using Test
using Pulumi

@testset "Pulumi.jl" begin
    @testset "Enums" begin
        include("enums_test.jl")
    end

    @testset "Errors" begin
        include("errors_test.jl")
    end

    @testset "Unknown" begin
        include("unknown_test.jl")
    end

    @testset "Output" begin
        include("output_test.jl")
    end

    @testset "Resource" begin
        include("resource_test.jl")
    end

    @testset "Context" begin
        include("context_test.jl")
    end

    @testset "Config" begin
        include("config_test.jl")
    end

    @testset "Export" begin
        include("export_test.jl")
    end

    @testset "Invoke" begin
        include("invoke_test.jl")
    end

    @testset "Dependency" begin
        include("dependency_test.jl")
    end

    @testset "Type Stability" begin
        include("type_stability_test.jl")
    end

    @testset "Aqua" begin
        include("aqua_test.jl")
    end

    @testset "Contract Tests" begin
        include("contract/register_resource_test.jl")
        include("contract/register_outputs_test.jl")
        include("contract/invoke_test.jl")
        include("contract/language_runtime_test.jl")
        include("contract/engine_client_test.jl")
    end

    @testset "Integration Tests" begin
        include("integration/parallel_test.jl")
        include("integration/component_test.jl")
        include("integration/export_test.jl")
        include("integration/conformance_test.jl")
        include("integration/pulumi_cli_test.jl")
    end

    @testset "Benchmarks" begin
        include("benchmark_test.jl")
    end
end
