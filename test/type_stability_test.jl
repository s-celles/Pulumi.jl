@testset "Type Stability" begin
    @testset "Output type stability" begin
        # Output preserves type parameter
        o_int = Output(42)
        @test typeof(o_int) == Output{Int64}

        o_str = Output("hello")
        @test typeof(o_str) == Output{String}

        o_vec = Output([1, 2, 3])
        @test typeof(o_vec) == Output{Vector{Int64}}
    end

    @testset "apply preserves type" begin
        o = Output(10)
        o2 = apply(x -> x * 2, o)
        @test typeof(o2) == Output{Int64}

        o3 = apply(x -> string(x), o)
        @test typeof(o3) == Output{String}
    end

    @testset "all type inference" begin
        o1, o2, o3 = Output(1), Output(2), Output(3)
        combined = Pulumi.all(o1, o2, o3)  # Use Pulumi.all to avoid conflict with Base.all
        @test typeof(combined) == Output{Tuple{Int64, Int64, Int64}}
    end
end
