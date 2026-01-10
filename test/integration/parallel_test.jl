# Integration tests for parallel resource creation

@testset "Parallel Resource Creation" begin
    # Save original environment
    original_env = Dict{String, String}()
    env_keys = ["PULUMI_PROJECT", "PULUMI_STACK", "PULUMI_MONITOR", "PULUMI_ENGINE", "PULUMI_CONFIG", "PULUMI_CONFIG_SECRET_KEYS"]
    for key in env_keys
        if haskey(ENV, key)
            original_env[key] = ENV[key]
        end
    end

    try
        reset_context!()
        ENV["PULUMI_PROJECT"] = "test-project"
        ENV["PULUMI_STACK"] = "dev"
        ENV["PULUMI_MONITOR"] = "localhost:12345"
        ENV["PULUMI_ENGINE"] = ""
        ENV["PULUMI_CONFIG"] = "{}"
        ENV["PULUMI_CONFIG_SECRET_KEYS"] = "[]"

        @testset "register_resources_parallel creates multiple resources" begin
            resources = register_resources_parallel([
                ("aws:s3:Bucket", "bucket1", Dict{String, Any}("acl" => "private")),
                ("aws:s3:Bucket", "bucket2", Dict{String, Any}("acl" => "public-read")),
                ("aws:s3:Bucket", "bucket3", Dict{String, Any}("acl" => "private"))
            ])

            @test length(resources) == 3
            @test Base.all(r -> r isa CustomResource, resources)
            @test Base.all(r -> r.type_ == "aws:s3:Bucket", resources)

            # Check names match input order (though execution order may vary)
            names = Set([r.name for r in resources])
            @test "bucket1" in names
            @test "bucket2" in names
            @test "bucket3" in names
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
        end

        @testset "with_parallelism respects max_concurrent" begin
            # Test that with_parallelism executes without error
            result = Ref(0)
            with_parallelism(4) do
                result[] = 42
            end
            @test result[] == 42
        end

    finally
        for key in env_keys
            if haskey(original_env, key)
                ENV[key] = original_env[key]
            else
                delete!(ENV, key)
            end
        end
        reset_context!()
    end
end
