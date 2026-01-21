# Contract tests for RegisterResource RPC
# T023: Contract test for MonitorClient.register_resource_rpc()
# These tests verify compliance with the Pulumi gRPC contract

@testset "RegisterResource Contract" begin
    @testset "MonitorClient structure" begin
        # Verify MonitorClient exists with required fields
        @test isdefined(Pulumi, :MonitorClient)

        # Create client
        client = MonitorClient("localhost:50051")
        @test client isa MonitorClient
        @test client.address == "localhost:50051"
        @test !client.connected
        @test client.channel === nothing
    end

    @testset "Connection requirement" begin
        # Contract: MUST throw GRPCError when not connected
        client = MonitorClient("localhost:50051")
        @test !client.connected

        request = Dict{String, Any}(
            "type" => "test:test:Test",
            "name" => "test"
        )

        # Should throw GRPCError with code 14 (UNAVAILABLE)
        @test_throws GRPCError register_resource_rpc(client, request)

        try
            register_resource_rpc(client, request)
        catch e
            @test e isa GRPCError
            @test e.code == 14  # UNAVAILABLE
            @test e.retryable == true
        end
    end

    @testset "Dict to Struct conversion" begin
        # Contract: MUST serialize Julia Dict to Struct for object field
        # Test the internal conversion functions

        # Test basic types
        d = Dict{String, Any}(
            "stringProp" => "value",
            "numberProp" => 42,
            "boolProp" => true,
            "nullProp" => nothing,
            "arrayProp" => ["a", "b", "c"],
            "nestedProp" => Dict{String, Any}(
                "inner" => "innerValue"
            )
        )

        struct_val = Pulumi.dict_to_struct(d)
        @test struct_val isa Pulumi.pulumirpc.google.protobuf.Struct
        @test haskey(struct_val.fields, "stringProp")
        @test haskey(struct_val.fields, "numberProp")
        @test haskey(struct_val.fields, "boolProp")
        @test haskey(struct_val.fields, "nullProp")
        @test haskey(struct_val.fields, "arrayProp")
        @test haskey(struct_val.fields, "nestedProp")

        # Test round-trip conversion
        result = Pulumi.struct_to_dict(struct_val)
        @test result["stringProp"] == "value"
        @test result["numberProp"] == 42.0
        @test result["boolProp"] == true
        @test result["nullProp"] === nothing
        @test result["arrayProp"] == ["a", "b", "c"]
        @test result["nestedProp"]["inner"] == "innerValue"
    end

    @testset "Request builder function" begin
        # Test that _build_register_resource_request creates valid protobuf messages
        request = Dict{String, Any}(
            "type" => "aws:s3/bucket:Bucket",
            "name" => "my-bucket",
            "parent" => "urn:pulumi:stack::project::component::parent",
            "custom" => true,
            "protect" => false,
            "dependencies" => String["urn:pulumi:stack::project::res::dep1"],
            "provider" => "urn:pulumi:stack::project::provider",
            "object" => Dict{String, Any}("bucketName" => "test-bucket"),
            "propertyDependencies" => Dict{String, Any}(
                "bucketName" => ["urn:pulumi:stack::project::res::dep2"]
            )
        )

        pb_request = Pulumi._build_register_resource_request(request)
        @test pb_request isa Pulumi.pulumirpc.RegisterResourceRequest
        @test pb_request.var"#type" == "aws:s3/bucket:Bucket"
        @test pb_request.name == "my-bucket"
        @test pb_request.parent == "urn:pulumi:stack::project::component::parent"
        @test pb_request.custom == true
        @test pb_request.protect == false
        @test "urn:pulumi:stack::project::res::dep1" in pb_request.dependencies
        @test pb_request.provider == "urn:pulumi:stack::project::provider"
        @test pb_request.object !== nothing
    end

    @testset "Address parsing" begin
        # Test address parsing helper
        host, port = Pulumi._parse_address("localhost:50051")
        @test host == "localhost"
        @test port == 50051

        host, port = Pulumi._parse_address("127.0.0.1:8080")
        @test host == "127.0.0.1"
        @test port == 8080

        # With protocol prefix
        host, port = Pulumi._parse_address("http://localhost:50051")
        @test host == "localhost"
        @test port == 50051
    end

    @testset "Function signatures" begin
        # Verify required functions exist
        @test isdefined(Pulumi, :register_resource_rpc)
        @test isdefined(Pulumi, :_build_register_resource_request)
        @test isdefined(Pulumi, :dict_to_struct)
        @test isdefined(Pulumi, :struct_to_dict)
        @test isdefined(Pulumi, :_parse_address)
    end
end
