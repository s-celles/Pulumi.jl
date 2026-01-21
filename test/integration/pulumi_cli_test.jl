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

    # Full integration tests with actual Pulumi CLI
    # These require: Pulumi CLI installed, test project, network connectivity
    if get(ENV, "PULUMI_TEST_INTEGRATION", "false") == "true"
        @testset "Pulumi Preview Integration" begin
            mktempdir() do dir
                # Create minimal Pulumi project
                pulumi_yaml = joinpath(dir, "Pulumi.yaml")
                write(pulumi_yaml, """
name: test-julia-project
runtime:
  name: julia
  options:
    binary: $(Base.julia_cmd().exec[1])
description: Test project for Julia Pulumi integration
""")

                main_jl = joinpath(dir, "Pulumi.jl")
                write(main_jl, """
# Minimal Pulumi program for integration test
using Pulumi

# T031: Resource registration test
# In a real scenario, this would register a resource
# For now, just verify context is available
ctx = get_context()

# T040: Logging test
log_info("Integration test running")

# T054: Preview mode test
if is_dry_run()
    log_info("Running in preview mode")
end

# Export some outputs for verification
export_value("test_output", "integration_test_passed")
""")

                cd(dir) do
                    # Initialize a local backend
                    run(`pulumi login --local`)
                    run(`pulumi stack init test-stack`)

                    # Run preview (T054: preview mode test)
                    result = read(`pulumi preview --non-interactive --json`, String)
                    @test occursin("test-julia-project", result)
                end
            end
        end
    else
        @info "Skipping Pulumi CLI integration tests (set PULUMI_TEST_INTEGRATION=true to enable)"
    end
end
