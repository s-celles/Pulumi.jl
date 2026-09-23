# Integration tests for Pulumi CLI integration
# These tests verify end-to-end functionality with the Pulumi CLI

@testset "Pulumi CLI Integration" begin
    @testset "LanguageRuntime Server" begin
        # T022: Integration test for Pulumi CLI
        @testset "Server exports exist" begin
            # Verify all required exports are available
            @test isdefined(Pulumi, :JuliaLanguageRuntime)
            @test isdefined(Pulumi, :LanguageRuntimeServer)
            @test isdefined(Pulumi, :create_language_runtime_server)
            @test isdefined(Pulumi, :start_and_print_port!)
            @test isdefined(Pulumi, :run_server)
            @test isdefined(Pulumi, :stop_server!)
        end

        @testset "Runtime initialization" begin
            # Test that JuliaLanguageRuntime can be created
            runtime = JuliaLanguageRuntime()
            @test runtime isa JuliaLanguageRuntime
            @test !runtime.initialized
            @test runtime.engine_address == ""
        end
    end

    @testset "gRPC Status Codes" begin
        # Verify gRPC status code mappings exist
        @test isdefined(Pulumi, :GRPCStatusCode)
        @test isdefined(Pulumi, :exception_to_grpc_code)
        @test isdefined(Pulumi, :is_retryable_grpc_code)
    end

    @testset "gRPC Log Severity" begin
        # Verify log severity mappings exist
        @test isdefined(Pulumi, :GRPCLogSeverity)
        @test isdefined(Pulumi, :log_severity_to_grpc)

        # Test log severity conversion
        @test Pulumi.log_severity_to_grpc("debug") == Pulumi.GRPCLogSeverity.DEBUG
        @test Pulumi.log_severity_to_grpc("info") == Pulumi.GRPCLogSeverity.INFO
        @test Pulumi.log_severity_to_grpc("warning") == Pulumi.GRPCLogSeverity.WARNING
        @test Pulumi.log_severity_to_grpc("error") == Pulumi.GRPCLogSeverity.ERROR
    end

    @testset "Client Exports" begin
        # T031: Verify resource registration client exports
        @test isdefined(Pulumi, :MonitorClient)
        @test isdefined(Pulumi, :EngineClient)
        @test isdefined(Pulumi, :connect!)
        @test isdefined(Pulumi, :disconnect!)
        @test isdefined(Pulumi, :register_resource_rpc)
        @test isdefined(Pulumi, :register_resource_outputs_rpc)
        @test isdefined(Pulumi, :invoke_rpc)
        @test isdefined(Pulumi, :log_rpc)
    end

    @testset "Serialization Functions" begin
        # T031: Test Dict to Struct conversion (used for resource properties)
        @test isdefined(Pulumi, :dict_to_struct)
        @test isdefined(Pulumi, :struct_to_dict)

        # Test roundtrip serialization
        d = Dict{String, Any}(
            "name" => "test-resource",
            "tags" => Dict{String, Any}("env" => "test"),
            "count" => 42
        )
        s = Pulumi.dict_to_struct(d)
        result = Pulumi.struct_to_dict(s)
        @test result["name"] == "test-resource"
        @test result["tags"]["env"] == "test"
        @test result["count"] == 42.0
    end

    @testset "Logging Functions" begin
        # T040: Verify logging function exports
        @test isdefined(Pulumi, :log_debug)
        @test isdefined(Pulumi, :log_info)
        @test isdefined(Pulumi, :log_warn)
        @test isdefined(Pulumi, :log_error)
    end

    @testset "Invoke Functions" begin
        # T047: Verify invoke function exports
        @test isdefined(Pulumi, :invoke)
    end

    @testset "Preview Mode Support" begin
        # T054: Verify preview mode exports
        @test isdefined(Pulumi, :is_dry_run)

        # Test Unknown type for preview mode
        @test isdefined(Pulumi, :Unknown)

        # Create unknown output (for preview mode)
        unknown_output = Output{String}()
        @test !unknown_output.is_known
        @test unknown_output.value isa Pulumi.Unknown
    end

    # A real deployment driven by the Pulumi CLI. This needs the CLI itself and
    # the language host installed as a plugin (`just plugin-install`), so it is
    # opt-in. It uses a temporary file backend and never touches the user's
    # login or their stacks.
    function julia_plugin_installed()
        Sys.which("pulumi-language-julia") === nothing || return true
        home = get(ENV, "PULUMI_HOME", joinpath(homedir(), ".pulumi"))
        plugins = joinpath(home, "plugins")
        isdir(plugins) || return false
        return Base.any(startswith("language-julia-v"), readdir(plugins))
    end

    if get(ENV, "PULUMI_TEST_INTEGRATION", "false") != "true"
        @info "Skipping Pulumi CLI integration tests (set PULUMI_TEST_INTEGRATION=true to enable)"
    elseif Sys.which("pulumi") === nothing
        @info "Skipping Pulumi CLI integration tests (the pulumi CLI is not on PATH)"
    elseif !julia_plugin_installed()
        @info "Skipping Pulumi CLI integration tests (run `just plugin-install` first)"
    else
        @testset "A Julia program deploys end to end" begin
            repo = dirname(dirname(@__DIR__))

            mktempdir() do dir
                write(joinpath(dir, "Pulumi.yaml"), """
                name: julia-cli-test
                runtime: julia
                description: End-to-end check driven by the Pulumi CLI
                """)

                write(joinpath(dir, "Project.toml"), """
                name = "JuliaCliTest"
                uuid = "33333333-4444-5555-6666-777777777777"

                [deps]
                Pulumi = "90af1f71-c6d8-4a0a-9f87-1292e80e7fff"

                [sources]
                Pulumi = {path = "$(repo)"}
                """)

                write(joinpath(dir, "main.jl"), """
                using Pulumi

                log_info("integration program running")

                group = component("julia:test:Group", "demo") do _
                    return nothing
                end
                register_outputs(group, Dict{String, Any}("ready" => true))

                export_value("greeting", "hello from Julia")
                export_value("dryRun", is_dry_run())
                export_secret("token", "s3cr3t")
                """)

                # Resolve the program's environment up front; the CLI only
                # installs dependencies on demand.
                run(pipeline(addenv(
                    `$(Base.julia_cmd()) --project=$dir --startup-file=no -e "using Pkg; Pkg.instantiate()"`,
                    "JULIA_LOAD_PATH" => "@:@stdlib", "JULIA_PROJECT" => nothing,
                ); stdout = devnull, stderr = devnull))

                state = mkpath(joinpath(dir, "state"))
                pulumi(args...) = addenv(`pulumi $args`,
                    "PULUMI_BACKEND_URL" => "file://$(state)",
                    "PULUMI_CONFIG_PASSPHRASE" => "integration-test",
                    "PULUMI_SKIP_UPDATE_CHECK" => "true",
                )

                cd(dir) do
                    try
                        run(pipeline(pulumi("stack", "init", "dev"); stdout = devnull, stderr = devnull))

                        @testset "pulumi preview plans the resources" begin
                            output = read(pipeline(pulumi("preview", "--non-interactive"); stderr = devnull), String)
                            @test occursin("julia:test:Group", output)
                        end

                        @testset "pulumi up creates them and publishes the outputs" begin
                            run(pipeline(pulumi("up", "--yes", "--non-interactive"); stdout = devnull, stderr = devnull))

                            outputs = Pulumi.JSON.parse(read(pipeline(
                                pulumi("stack", "output", "--json", "--show-secrets"); stderr = devnull), String))

                            @test outputs["greeting"] == "hello from Julia"
                            # The program ran for real, not as a preview.
                            @test outputs["dryRun"] == false
                            @test outputs["token"] == "s3cr3t"
                        end

                        @testset "Secrets are masked unless asked for" begin
                            outputs = Pulumi.JSON.parse(read(pipeline(
                                pulumi("stack", "output", "--json"); stderr = devnull), String))

                            @test outputs["greeting"] == "hello from Julia"
                            @test outputs["token"] != "s3cr3t"
                        end

                        @testset "pulumi destroy removes them" begin
                            run(pipeline(pulumi("destroy", "--yes", "--non-interactive"); stdout = devnull, stderr = devnull))

                            output = read(pipeline(pulumi("stack", "output", "--json"); stderr = devnull), String)
                            @test Pulumi.JSON.parse(output) == Dict{String, Any}()
                        end
                    finally
                        try
                            run(pipeline(pulumi("stack", "rm", "--yes", "--force"); stdout = devnull, stderr = devnull))
                        catch
                            # The stack may not exist if init failed.
                        end
                    end
                end
            end
        end
    end
end
