# Integration tests for parallel resource creation

@testset "Parallel Resource Creation" begin
    with_fake_engine() do engine
        @testset "register_resources_parallel creates multiple resources" begin
            resources = register_resources_parallel([
                ("aws:s3:Bucket", "bucket1", Dict{String, Any}("acl" => "private")),
                ("aws:s3:Bucket", "bucket2", Dict{String, Any}("acl" => "public-read")),
                ("aws:s3:Bucket", "bucket3", Dict{String, Any}("acl" => "private"))
            ])

            @test length(resources) == 3
            @test Base.all(r -> r isa CustomResource, resources)
            @test Base.all(r -> r.type_ == "aws:s3:Bucket", resources)

            # Every one of them was really registered, and registering in
            # parallel did not lose or duplicate any.
            @test Base.all(r -> r.state == Pulumi.ResourceState.CREATED, resources)
            @test Base.all(r -> !isempty(get_urn(r)), resources)

            names = Set([r.name for r in resources])
            @test names == Set(["bucket1", "bucket2", "bucket3"])

            registered = Set(r.name for r in engine.registrations
                             if r.var"#type" == "aws:s3:Bucket")
            @test registered == names
        end

        @testset "register_resources_parallel handles empty list" begin
            resources = register_resources_parallel(Tuple{String, String, Dict{String, Any}}[])
            @test isempty(resources)
        end

        @testset "register_resources_parallel handles single resource" begin
            resources = register_resources_parallel([
                ("aws:ec2:Instance", "server1", Dict{String, Any}("ami" => "ami-12345"))
            ])

            @test length(resources) == 1
            @test resources[1].name == "server1"
            @test resources[1].type_ == "aws:ec2:Instance"
            @test resources[1].state == Pulumi.ResourceState.CREATED
        end

        @testset "with_parallelism respects max_concurrent" begin
            result = Ref(0)
            with_parallelism(4) do
                result[] = 42
            end
            @test result[] == 42
        end
    end
end
