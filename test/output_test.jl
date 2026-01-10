@testset "Output" begin
    @testset "Output creation" begin
        # Known value
        o = Output(42)
        @test o.value == 42
        @test o.is_known == true
        @test o.is_secret == false
        @test isempty(o.dependencies)

        # Secret value
        o_secret = Output("password"; is_secret=true)
        @test o_secret.value == "password"
        @test o_secret.is_secret == true

        # Unknown value uses Output{T}() constructor
        o_unknown = Output{Int}()
        @test o_unknown.is_known == false

        # With dependencies
        o_deps = Output("value"; dependencies=["urn:pulumi:stack::type::name"])
        @test length(o_deps.dependencies) == 1
        @test "urn:pulumi:stack::type::name" in o_deps.dependencies
    end

    @testset "Output apply" begin
        o = Output(10)

        # Simple transformation
        o2 = apply(x -> x * 2, o)
        @test o2.value == 20
        @test o2.is_known == true

        # Secret propagation
        o_secret = Output(5; is_secret=true)
        o3 = apply(x -> x + 1, o_secret)
        @test o3.value == 6
        @test o3.is_secret == true

        # Unknown propagation
        o_unknown = Output{Int}()  # Unknown output
        o4 = apply(x -> x * 2, o_unknown)
        @test o4.is_known == false
    end

    @testset "Output all" begin
        o1 = Output(1)
        o2 = Output(2)
        o3 = Output(3)

        # Combine outputs using varargs (use Pulumi.all to avoid conflict with Base.all)
        combined = Pulumi.all(o1, o2, o3)
        @test combined.is_known == true
        @test combined.value == (1, 2, 3)  # Returns tuple, not vector

        # With secret
        o_secret = Output(4; is_secret=true)
        combined_secret = Pulumi.all(o1, o_secret)
        @test combined_secret.is_secret == true

        # With unknown
        o_unknown = Output{Int}()  # Unknown output
        combined_unknown = Pulumi.all(o1, o_unknown)
        @test combined_unknown.is_known == false
    end

    @testset "Output show" begin
        o = Output(42)
        io = IOBuffer()
        show(io, o)
        @test String(take!(io)) == "Output{Int64}(42)"

        o_secret = Output("secret"; is_secret=true)
        io = IOBuffer()
        show(io, o_secret)
        @test String(take!(io)) == "Output{String}([secret])"

        # Unknown output uses Output{T}() constructor
        o_unknown = Output{Int}()
        io = IOBuffer()
        show(io, o_unknown)
        @test String(take!(io)) == "Output{Int64}(<unknown>)"
    end
end
