# Benchmark tests for performance targets per tasks.md
# T094: gRPC serialization <10ms
# T095: Startup time <2s

@testset "Benchmarks" begin
    @testset "Output creation benchmark" begin
        # Basic performance check
        start = time_ns()
        for _ in 1:1000
            Output(42)
        end
        elapsed = (time_ns() - start) / 1e6  # ms
        @test elapsed < 1000  # Should create 1000 outputs in under 1 second
    end

    @testset "DependencyGraph benchmark" begin
        start = time_ns()
        graph = DependencyGraph()
        for i in 1:100
            add_node!(graph, "node$i")
        end
        for i in 2:100
            add_edge!(graph, "node$i", "node$(i-1)")
        end
        topological_sort(graph)
        elapsed = (time_ns() - start) / 1e6  # ms
        @test elapsed < 1000  # Should complete in under 1 second
    end

    @testset "gRPC serialization benchmark (<10ms target)" begin
        # Create a complex nested structure
        complex_inputs = Dict{String, Any}(
            "string" => "hello world",
            "number" => 42,
            "float" => 3.14159,
            "bool" => true,
            "array" => [1, 2, 3, 4, 5],
            "nested" => Dict{String, Any}(
                "a" => 1,
                "b" => "two",
                "c" => [Dict("x" => 1), Dict("y" => 2)]
            ),
            "output" => Output("test-value"),
            "secret" => Output("secret-value"; is_secret=true)
        )

        # Access internal serialization functions
        serialize_struct = Pulumi.serialize_struct
        deserialize_struct = Pulumi.deserialize_struct

        # Warm up
        serialize_struct(complex_inputs)

        # Benchmark serialization
        start = time_ns()
        for _ in 1:100
            serialized = serialize_struct(complex_inputs)
        end
        elapsed = (time_ns() - start) / 1e6  # ms
        per_call = elapsed / 100

        @test per_call < 10  # <10ms per serialization (target from tasks.md)

        # Also test deserialization
        serialized = serialize_struct(complex_inputs)
        start = time_ns()
        for _ in 1:100
            deserialize_struct(serialized)
        end
        elapsed = (time_ns() - start) / 1e6
        per_call = elapsed / 100

        @test per_call < 10  # <10ms per deserialization
    end

    @testset "apply() type inference benchmark" begin
        output = Output(42)

        # Warm up
        apply(x -> x * 2, output)

        # Benchmark
        start = time_ns()
        for _ in 1:1000
            result = apply(x -> x * 2, output)
        end
        elapsed = (time_ns() - start) / 1e6

        @test elapsed < 1000  # 1000 applies in under 1 second
    end

    @testset "all() combining benchmark" begin
        outputs = [Output(i) for i in 1:10]

        # Warm up
        Pulumi.all(outputs...)

        # Benchmark
        start = time_ns()
        for _ in 1:100
            Pulumi.all(outputs...)
        end
        elapsed = (time_ns() - start) / 1e6

        @test elapsed < 1000  # 100 combines in under 1 second
    end
end
