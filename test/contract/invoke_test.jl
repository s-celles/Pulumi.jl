# Contract tests for Invoke RPC
# T041-T042: Contract tests for MonitorClient.invoke_rpc()
# These tests verify compliance with the Pulumi gRPC contract for provider invocations

@testset "Invoke Contract" begin
    @testset "Function exists" begin
        # Verify invoke_rpc exists
        @test isdefined(Pulumi, :invoke_rpc)
    end

    @testset "Connection requirement" begin
        # Contract: MUST throw GRPCError when not connected
        client = MonitorClient("localhost:50051")
        @test !client.connected

        request = Dict{String, Any}(
            "tok" => "aws:ec2/getAmi:getAmi",
            "args" => Dict{String, Any}("owners" => ["amazon"])
        )

        # Should throw GRPCError with code 14 (UNAVAILABLE)
        @test_throws GRPCError invoke_rpc(client, request)

        try
            invoke_rpc(client, request)
        catch e
            @test e isa GRPCError
            @test e.code == 14  # UNAVAILABLE
            @test e.retryable == true
        end
    end

    @testset "Request format" begin
        # Verify ResourceInvokeRequest can be constructed
        @test isdefined(Pulumi.pulumirpc, :ResourceInvokeRequest)

        # Test request fields
        tok = "aws:ec2/getAmi:getAmi"
        args = Dict{String, Any}(
            "owners" => ["amazon"],
            "filters" => [
                Dict{String, Any}("name" => "state", "values" => ["available"])
            ]
        )

        args_struct = Pulumi.dict_to_struct(args)
        @test args_struct isa Pulumi.pulumirpc.google.protobuf.Struct
        @test haskey(args_struct.fields, "owners")
        @test haskey(args_struct.fields, "filters")
    end

    @testset "Arguments serialization" begin
        # Test various argument types serialize correctly
        args = Dict{String, Any}(
            "stringArg" => "value",
            "numberArg" => 42,
            "boolArg" => true,
            "arrayArg" => ["a", "b", "c"],
            "objectArg" => Dict{String, Any}(
                "nested" => "value"
            )
        )

        struct_val = Pulumi.dict_to_struct(args)
        result = Pulumi.struct_to_dict(struct_val)

        @test result["stringArg"] == "value"
        @test result["numberArg"] == 42.0
        @test result["boolArg"] == true
        @test result["arrayArg"] == ["a", "b", "c"]
        @test result["objectArg"]["nested"] == "value"
    end

    @testset "Response structure" begin
        # Verify InvokeResponse fields
        @test isdefined(Pulumi.pulumirpc, :InvokeResponse)

        # InvokeResponse should have:
        # - return: Struct (output properties)
        # - failures: Vector{CheckFailure}
    end

    @testset "Failure handling" begin
        # Contract: Failures should be deserialized as array of property/reason pairs
        @test isdefined(Pulumi.pulumirpc, :CheckFailure)

        # CheckFailure should have:
        # - property: String
        # - reason: String
    end

    @testset "Token format" begin
        # Contract: tok MUST follow provider token format
        # Format: {provider}:{module}/{type}:{function}

        # Valid tokens
        @test occursin(":", "aws:ec2/getAmi:getAmi")
        @test occursin("/", "aws:ec2/getAmi:getAmi")

        # Common AWS data source tokens
        tokens = [
            "aws:ec2/getAmi:getAmi",
            "aws:s3/getBucket:getBucket",
            "aws:iam/getPolicy:getPolicy",
            "gcp:compute/getImage:getImage",
            "azure:compute/getImage:getImage"
        ]

        for tok in tokens
            parts = split(tok, ":")
            @test length(parts) == 3  # provider:module/type:function
        end
    end
end
