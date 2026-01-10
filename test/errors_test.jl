@testset "PulumiError hierarchy" begin
    # PulumiError is abstract, test concrete types
    @test PulumiError <: Exception
    @test ResourceError <: PulumiError
    @test GRPCError <: PulumiError
    @test ConfigMissingError <: PulumiError
    @test DependencyError <: PulumiError
end

@testset "ResourceError" begin
    err = ResourceError(
        "urn:pulumi:dev::project::aws:s3:Bucket::test",
        "Failed to create resource"
    )
    @test err isa PulumiError
    @test err.urn == "urn:pulumi:dev::project::aws:s3:Bucket::test"
    @test err.message == "Failed to create resource"
    @test err.cause === nothing

    io = IOBuffer()
    showerror(io, err)
    output = String(take!(io))
    @test contains(output, "ResourceError")
    @test contains(output, "aws:s3:Bucket::test")
end

@testset "GRPCError" begin
    err = GRPCError(14, "Service unavailable", true)
    @test err isa PulumiError
    @test err.code == 14
    @test err.message == "Service unavailable"
    @test err.retryable == true

    io = IOBuffer()
    showerror(io, err)
    output = String(take!(io))
    @test contains(output, "GRPCError")
    @test contains(output, "14")
    @test contains(output, "Service unavailable")
end

@testset "ConfigMissingError" begin
    err = ConfigMissingError("apiKey", "my-project")
    @test err isa PulumiError
    @test err.key == "apiKey"
    @test err.namespace == "my-project"

    io = IOBuffer()
    showerror(io, err)
    output = String(take!(io))
    @test contains(output, "ConfigMissingError")
    @test contains(output, "my-project:apiKey")
end

@testset "DependencyError" begin
    err = DependencyError("Cycle detected", ["a", "b", "a"])
    @test err isa PulumiError
    @test err.resources == ["a", "b", "a"]
    @test err.message == "Cycle detected"

    io = IOBuffer()
    showerror(io, err)
    output = String(take!(io))
    @test contains(output, "DependencyError")
    @test contains(output, "Cycle detected")
end
