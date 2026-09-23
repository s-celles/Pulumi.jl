# Tests for the LanguageRuntime gRPC server lifecycle and its handlers.
#
# These cover the pieces the Pulumi CLI relies on when it launches
# `pulumi-language-julia`: ephemeral port binding and port announcement,
# dependency installation and dependency reporting.

@testitem "LanguageRuntime Server" setup=[TestSupport] begin
    using Sockets
    @testset "Ephemeral port binding" begin
        # The Pulumi plugin protocol launches the host with no port and reads
        # the chosen port from stdout, so port 0 must be accepted.
        server = create_language_runtime_server("127.0.0.1", 0)
        @test server isa LanguageRuntimeServer

        port, printed = TestSupport.capture_stdout() do
            start_and_print_port!(server)
        end

        try
            # The announced port must be the port actually bound, not a
            # hard-coded placeholder.
            @test port isa Integer
            @test 1 <= port <= 65535
            @test server.port == port
            @test strip(printed) == string(port)

            # And something must really be listening there.
            socket = Sockets.connect("127.0.0.1", port)
            @test isopen(socket)
            close(socket)
        finally
            stop_server!(server)
        end
    end

    @testset "Explicit port is honoured" begin
        port = TestSupport.free_port()
        server = create_language_runtime_server("127.0.0.1", port)
        @test server.port == port

        announced, printed = TestSupport.capture_stdout() do
            start_and_print_port!(server)
        end

        try
            @test announced == port
            @test strip(printed) == string(port)
        finally
            stop_server!(server)
        end
    end

    @testset "Invalid port is rejected" begin
        @test_throws ArgumentError create_language_runtime_server("127.0.0.1", -1)
        @test_throws ArgumentError create_language_runtime_server("127.0.0.1", 70000)
    end
end

@testitem "GetProgramDependencies handler" setup=[TestSupport] begin
    ctx = Pulumi.ServerContext(method = "GetProgramDependencies")

    @testset "Parses Project.toml dependencies" begin
        mktempdir() do dir
            write(joinpath(dir, "Project.toml"), """
            name = "MyProgram"
            uuid = "11111111-2222-3333-4444-555555555555"
            version = "0.3.0"

            [deps]
            JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
            Pulumi = "90af1f71-c6d8-4a0a-9f87-1292e80e7fff"

            [compat]
            JSON = "1"
            Pulumi = "0.1"
            julia = "1.10"
            """)

            runtime = JuliaLanguageRuntime()
            request = Pulumi.GetProgramDependenciesRequest("", dir, "", false, nothing)
            response = Pulumi.handle_get_program_dependencies(runtime, ctx, request)

            found = Dict(d.name => d.version for d in response.dependencies)
            @test haskey(found, "JSON")
            @test haskey(found, "Pulumi")
            # `julia` is a compat entry, not a package dependency.
            @test !haskey(found, "julia")
            # Versions come from the [compat] bounds when no manifest is present.
            @test found["JSON"] == "1"
            @test found["Pulumi"] == "0.1"
        end
    end

    @testset "Manifest versions take precedence over compat bounds" begin
        mktempdir() do dir
            write(joinpath(dir, "Project.toml"), """
            name = "MyProgram"
            uuid = "11111111-2222-3333-4444-555555555555"

            [deps]
            JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"

            [compat]
            JSON = "1"
            """)
            write(joinpath(dir, "Manifest.toml"), """
            julia_version = "1.10.0"
            manifest_format = "2.0"

            [[deps.JSON]]
            deps = ["Dates", "Mmap", "Parsers", "Unicode"]
            git-tree-sha1 = "0000000000000000000000000000000000000000"
            uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
            version = "1.9.0"
            """)

            runtime = JuliaLanguageRuntime()
            request = Pulumi.GetProgramDependenciesRequest("", dir, "", false, nothing)
            response = Pulumi.handle_get_program_dependencies(runtime, ctx, request)

            found = Dict(d.name => d.version for d in response.dependencies)
            @test found["JSON"] == "1.9.0"
        end
    end

    @testset "Falls back to the runtime program directory" begin
        mktempdir() do dir
            write(joinpath(dir, "Project.toml"), """
            name = "MyProgram"
            uuid = "11111111-2222-3333-4444-555555555555"

            [deps]
            Pulumi = "90af1f71-c6d8-4a0a-9f87-1292e80e7fff"
            """)

            runtime = JuliaLanguageRuntime()
            runtime.program_directory = dir
            request = Pulumi.GetProgramDependenciesRequest("", "", "", false, nothing)
            response = Pulumi.handle_get_program_dependencies(runtime, ctx, request)

            @test "Pulumi" in [d.name for d in response.dependencies]
        end
    end

    @testset "Missing Project.toml yields no dependencies" begin
        mktempdir() do dir
            runtime = JuliaLanguageRuntime()
            request = Pulumi.GetProgramDependenciesRequest("", dir, "", false, nothing)
            response = Pulumi.handle_get_program_dependencies(runtime, ctx, request)

            @test isempty(response.dependencies)
        end
    end
end

@testitem "InstallDependencies handler" setup=[TestSupport] begin
    ctx = Pulumi.ServerContext(method = "InstallDependencies")

    @testset "Instantiates the project and streams output" begin
        mktempdir() do dir
            # A project with no dependencies still exercises the real
            # Pkg.instantiate() code path and resolves instantly.
            write(joinpath(dir, "Project.toml"), """
            name = "MyProgram"
            uuid = "11111111-2222-3333-4444-555555555555"
            version = "0.1.0"

            [deps]
            """)

            runtime = JuliaLanguageRuntime()
            request = Pulumi.InstallDependenciesRequest(dir, false, nothing, false, false)
            stream, sent, _ = TestSupport.collect_stream(Pulumi.InstallDependenciesResponse)

            Pulumi.handle_install_dependencies(runtime, ctx, request, stream)

            @test !isempty(sent)
            stderr_text = join(String(copy(m.stderr)) for m in sent)
            # A clean instantiate must not report an error.
            @test !occursin("ERROR", stderr_text)

            # The environment must now be resolved.
            @test isfile(joinpath(dir, "Manifest.toml"))
        end
    end

    @testset "Reports failures on stderr instead of throwing" begin
        mktempdir() do dir
            write(joinpath(dir, "Project.toml"), "this is not valid TOML {{{\n")

            runtime = JuliaLanguageRuntime()
            request = Pulumi.InstallDependenciesRequest(dir, false, nothing, false, false)
            stream, sent, _ = TestSupport.collect_stream(Pulumi.InstallDependenciesResponse)

            Pulumi.handle_install_dependencies(runtime, ctx, request, stream)

            @test !isempty(sent)
            stderr_text = join(String(copy(m.stderr)) for m in sent)
            @test !isempty(strip(stderr_text))
        end
    end

    @testset "Missing directory is reported, not raised" begin
        runtime = JuliaLanguageRuntime()
        missing_dir = joinpath(tempdir(), "pulumi-jl-does-not-exist-$(rand(UInt32))")
        request = Pulumi.InstallDependenciesRequest(missing_dir, false, nothing, false, false)
        stream, sent, _ = TestSupport.collect_stream(Pulumi.InstallDependenciesResponse)

        Pulumi.handle_install_dependencies(runtime, ctx, request, stream)

        stderr_text = join(String(copy(m.stderr)) for m in sent)
        @test !isempty(strip(stderr_text))
    end
end

@testitem "Run handler execution context" setup=[TestSupport] begin
    @testset "Propagates project, stack and organization from the request" begin
        saved = Dict(
            key => get(ENV, key, nothing) for key in
            ("PULUMI_PROJECT", "PULUMI_STACK", "PULUMI_ORGANIZATION", "PULUMI_MONITOR",
             "PULUMI_ENGINE", "PULUMI_DRY_RUN", "PULUMI_PARALLEL")
        )

        try
            # Running a program needs a live resource monitor: the host
            # registers the root stack resource before the program runs.
            TestSupport.with_fake_engine() do engine
                mktempdir() do dir
                    program = joinpath(dir, "main.jl")
                    write(program, "# empty Pulumi program\n")

                    runtime = JuliaLanguageRuntime()
                    runtime.initialized = true
                    runtime.program_directory = dir
                    runtime.engine_address = engine.address

                    ctx = Pulumi.ServerContext(method = "Run")
                    request = Pulumi.RunRequest(
                        "my-project",           # project
                        "my-stack",             # stack
                        dir,                    # pwd
                        "main.jl",              # program
                        String[],               # args
                        Dict{String,String}(),  # config
                        true,                   # dryRun
                        Int32(4),               # parallel
                        engine.address,         # monitor_address
                        false,                  # queryMode
                        String[],               # configSecretKeys
                        "my-org",               # organization
                        nothing,                # configPropertyMap
                        nothing,                # info
                        "",                     # loader_target
                        false,                  # attach_debugger
                    )

                    response = Pulumi.handle_run(runtime, ctx, request)

                    @test response.error == ""

                    # The root stack resource is registered for the program.
                    @test Base.any(r -> r.var"#type" == "pulumi:pulumi:Stack",
                                   engine.registrations)
                    # The request fields, not non-existent runtime fields, drive the
                    # environment the program observes.
                    @test ENV["PULUMI_PROJECT"] == "my-project"
                    @test ENV["PULUMI_STACK"] == "my-stack"
                    @test ENV["PULUMI_ORGANIZATION"] == "my-org"
                    @test ENV["PULUMI_DRY_RUN"] == "true"
                    @test ENV["PULUMI_PARALLEL"] == "4"
                end
            end
        finally
            Pulumi.reset_context!()
            for (key, value) in saved
                if value === nothing
                    delete!(ENV, key)
                else
                    ENV[key] = value
                end
            end
        end
    end

    @testset "Uninitialized runtime is rejected" begin
        runtime = JuliaLanguageRuntime()
        ctx = Pulumi.ServerContext(method = "Run")
        request = Pulumi.RunRequest(
            "p", "s", "", "main.jl", String[], Dict{String,String}(), false,
            Int32(0), "", false, String[], "", nothing, nothing, "", false,
        )

        response = Pulumi.handle_run(runtime, ctx, request)
        @test occursin("not initialized", response.error)
    end
end

@testitem "Graceful shutdown" setup=[TestSupport] begin
    @testset "stop_server! is idempotent" begin
        server = create_language_runtime_server("127.0.0.1", 0)

        # Never started: stopping is a no-op rather than an error.
        @test stop_server!(server) === nothing

        TestSupport.capture_stdout() do
            start_and_print_port!(server)
        end
        @test stop_server!(server) === nothing
        @test stop_server!(server) === nothing
    end

    # Signal handling itself is not exercised here. Delivering a signal to a
    # Julia process that is still JIT-compiling its serving loop wedges it, so
    # a subprocess test would assert on JIT timing rather than on the shutdown
    # logic, and was flaky for exactly that reason. What the host guarantees
    # once it is serving — a clean stop and a released port on SIGINT and
    # SIGTERM — is verified by hand with `just plugin-run`.
    @testset "run_language_host is the entry point" begin
        @test isdefined(Pulumi, :run_language_host)

        # The entry point script must call it rather than re-implement the
        # lifecycle, so the atexit-based shutdown always applies.
        script = read(joinpath(dirname(@__DIR__), "src", "bin", "pulumi-language-julia"), String)
        @test occursin("run_language_host()", script)
    end
end
