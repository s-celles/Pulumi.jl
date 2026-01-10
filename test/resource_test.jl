@testset "Resource" begin
    @testset "URN parsing" begin
        # Basic URN: urn:pulumi:{stack}::{project}::{type}::{name}
        urn_str = "urn:pulumi:dev::my-project::aws:s3:Bucket::my-bucket"
        urn = URN(urn_str)
        @test urn.stack == "dev"
        @test urn.project == "my-project"
        @test urn.type_ == "aws:s3:Bucket"
        @test urn.name == "my-bucket"
        @test urn.parent_type === nothing

        # URN with parent type (uses $ to separate parent from child type)
        urn_parent_str = "urn:pulumi:prod::project::my:module:Parent\$aws:ec2:Instance::child"
        urn_parent = URN(urn_parent_str)
        @test urn_parent.stack == "prod"
        @test urn_parent.project == "project"
        @test urn_parent.parent_type == "my:module:Parent"
        @test urn_parent.type_ == "aws:ec2:Instance"
        @test urn_parent.name == "child"

        # Invalid URN format
        @test_throws ArgumentError URN("invalid-urn")
        @test_throws ArgumentError URN("urn:not-pulumi:stack::type::name")
    end

    @testset "URN string conversion" begin
        urn = URN("dev", "my-project", nothing, "aws:s3:Bucket", "my-bucket")
        @test string(urn) == "urn:pulumi:dev::my-project::aws:s3:Bucket::my-bucket"

        urn_parent = URN("prod", "project", "my:module:Parent", "aws:ec2:Instance", "child")
        @test string(urn_parent) == "urn:pulumi:prod::project::my:module:Parent\$aws:ec2:Instance::child"
    end

    @testset "ResourceOptions" begin
        # Default options
        opts = ResourceOptions()
        @test opts.parent === nothing
        @test isempty(opts.depends_on)
        @test opts.protect == false
        @test opts.provider === nothing

        # Custom options
        opts_custom = ResourceOptions(
            protect=true,
            delete_before_replace=true,
            retain_on_delete=true
        )
        @test opts_custom.protect == true
        @test opts_custom.delete_before_replace == true
        @test opts_custom.retain_on_delete == true
    end

    @testset "CustomResource creation" begin
        resource = CustomResource(
            "urn:pulumi:dev::project::aws:s3:Bucket::test",
            "aws:s3:Bucket",
            "test",
            Dict{String, Any}("acl" => "private"),
            Dict{String, Any}(),
            ResourceOptions(),
            ResourceState.PENDING
        )
        @test get_urn(resource) == "urn:pulumi:dev::project::aws:s3:Bucket::test"
        @test get_name(resource) == "test"
        @test get_type(resource) == "aws:s3:Bucket"
        @test resource.state == ResourceState.PENDING
    end

    @testset "ComponentResource creation" begin
        component = ComponentResource(
            "urn:pulumi:dev::project::my:module:WebServer::web",
            "my:module:WebServer",
            "web",
            Resource[],
            ResourceOptions(),
            ResourceState.PENDING
        )
        @test get_urn(component) == "urn:pulumi:dev::project::my:module:WebServer::web"
        @test get_name(component) == "web"
        @test get_type(component) == "my:module:WebServer"
        @test isempty(component.children)
    end

    @testset "ProviderResource creation" begin
        provider = ProviderResource(
            "urn:pulumi:dev::project::pulumi:providers:aws::aws-provider",
            "aws",
            "aws-provider",
            Dict{String, Any}("region" => "us-east-1"),
            ResourceOptions(),
            ResourceState.PENDING
        )
        @test provider.package == "aws"
        @test get_name(provider) == "aws-provider"
        @test get_type(provider) == "aws"
    end

    @testset "Resource show methods" begin
        resource = CustomResource(
            "", "aws:s3:Bucket", "test",
            Dict{String, Any}(), Dict{String, Any}(),
            ResourceOptions(), ResourceState.PENDING
        )

        io = IOBuffer()
        show(io, resource)
        output = String(take!(io))
        @test contains(output, "CustomResource")
        @test contains(output, "aws:s3:Bucket")
        @test contains(output, "test")
    end
end
