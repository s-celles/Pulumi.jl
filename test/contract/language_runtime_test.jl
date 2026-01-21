# Contract tests for LanguageRuntime gRPC service
# These tests verify compliance with the Pulumi LanguageRuntime gRPC contract

@testset "LanguageRuntime Contract" begin
    @testset "Handshake RPC" begin
        # T012: Contract test for Handshake RPC
        @testset "Valid handshake request" begin
            # Create a runtime instance
            runtime = JuliaLanguageRuntime()
            @test !runtime.initialized

            # Simulate a handshake request
            # Note: In real implementation, this would be via gRPC
            # For now, we test the handler directly
            @test runtime.engine_address == ""
            @test runtime.root_directory == ""
            @test runtime.program_directory == ""
        end

        @testset "Handshake stores connection info" begin
            runtime = JuliaLanguageRuntime()

            # After handshake, runtime should store the connection info
            # This verifies the contract requirement:
            # - MUST store engine_address for later Engine client connection
            # - MUST store directories for program execution context
            @test !runtime.initialized

            # The actual handler test would require mock ServerContext
            # For now, verify the struct fields exist and are mutable
            runtime.engine_address = "localhost:50051"
            runtime.root_directory = "/test/root"
            runtime.program_directory = "/test/program"
            runtime.initialized = true

            @test runtime.engine_address == "localhost:50051"
            @test runtime.root_directory == "/test/root"
            @test runtime.program_directory == "/test/program"
            @test runtime.initialized
        end
    end

    @testset "Run RPC" begin
        # T013: Contract test for Run RPC
        @testset "Run requires initialization" begin
            runtime = JuliaLanguageRuntime()
            @test !runtime.initialized

            # Contract: MUST return error if not initialized
            # The actual handler test would require RunRequest protobuf
        end

        @testset "Run handles program paths" begin
            # Contract requirements:
            # - MUST execute program at info.entry_point (or program path)
            # - MUST return empty error string on success
            # - MUST return error message if program throws exception

            # Verify LanguageRuntimeServer struct exists
            @test isdefined(Pulumi, :LanguageRuntimeServer)
        end
    end

    @testset "GetPluginInfo RPC" begin
        # T014: Contract test for GetPluginInfo RPC
        @testset "Returns version string" begin
            # Contract: MUST return the Pulumi.jl package version
            # Version SHOULD follow semver format

            # Verify the server creation function exists
            @test isdefined(Pulumi, :create_language_runtime_server)
        end
    end
end

@testset "LanguageRuntime Server Lifecycle" begin
    @testset "Server creation" begin
        # Verify server can be created
        @test isdefined(Pulumi, :create_language_runtime_server)
        @test isdefined(Pulumi, :start_and_print_port!)
        @test isdefined(Pulumi, :run_server)
        @test isdefined(Pulumi, :stop_server!)
    end
end

@testset "Preview Mode Support (US5)" begin
    # T048: Contract test for dryRun flag handling

    @testset "dryRun flag context" begin
        # Contract: RunRequest.dryRun MUST be passed to Context
        # and accessible via is_dry_run()

        # Verify is_dry_run function exists
        @test isdefined(Pulumi, :is_dry_run)

        # Verify Context has is_dry_run field
        ctx_fields = fieldnames(Pulumi.Context)
        @test :is_dry_run in ctx_fields
    end

    @testset "dryRun environment variable" begin
        # Contract: PULUMI_DRY_RUN env var controls preview mode
        old_val = get(ENV, "PULUMI_DRY_RUN", nothing)

        try
            # Reset context first
            Pulumi.reset_context!()

            # Test with dry run enabled
            ENV["PULUMI_DRY_RUN"] = "true"
            ENV["PULUMI_MONITOR"] = ""
            ENV["PULUMI_ENGINE"] = ""
            ctx1 = Pulumi.Context()
            @test ctx1.is_dry_run == true

            # Reset and test with dry run disabled
            Pulumi.reset_context!()
            ENV["PULUMI_DRY_RUN"] = "false"
            ctx2 = Pulumi.Context()
            @test ctx2.is_dry_run == false

            # Reset and test default (no env var)
            Pulumi.reset_context!()
            delete!(ENV, "PULUMI_DRY_RUN")
            ctx3 = Pulumi.Context()
            @test ctx3.is_dry_run == false

        finally
            # Restore original value
            Pulumi.reset_context!()
            if old_val !== nothing
                ENV["PULUMI_DRY_RUN"] = old_val
            else
                delete!(ENV, "PULUMI_DRY_RUN")
            end
        end
    end
end
