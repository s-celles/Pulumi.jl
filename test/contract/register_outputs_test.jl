# Contract tests for RegisterResourceOutputs RPC
# T024: Contract test for MonitorClient.register_resource_outputs_rpc()
# These tests verify compliance with the Pulumi gRPC contract

@testset "RegisterResourceOutputs Contract" begin
    @testset "Function exists" begin
        # Verify register_resource_outputs_rpc exists
        @test isdefined(Pulumi, :register_resource_outputs_rpc)
    end

    @testset "Connection requirement" begin
        # Contract: MUST throw GRPCError when not connected
        client = MonitorClient("localhost:50051")
        @test !client.connected

        request = Dict{String, Any}(
            "urn" => "urn:pulumi:stack::project::custom:component:MyComponent::myComp",
            "outputs" => Dict{String, Any}()
        )

        # Should throw GRPCError with code 14 (UNAVAILABLE)
        @test_throws GRPCError register_resource_outputs_rpc(client, request)

        try
            register_resource_outputs_rpc(client, request)
        catch e
            @test e isa GRPCError
            @test e.code == 14  # UNAVAILABLE
            @test e.retryable == true
        end
    end

    @testset "Request format" begin
        # Verify RegisterResourceOutputsRequest can be constructed
        @test isdefined(Pulumi.pulumirpc, :RegisterResourceOutputsRequest)

        # Create a request manually
        urn = "urn:pulumi:stack::project::custom:component:MyComponent::myComp"
        outputs = Dict{String, Any}(
            "outputValue" => "result",
            "outputNumber" => 42
        )

        outputs_struct = Pulumi.dict_to_struct(outputs)
        pb_request = Pulumi.pulumirpc.RegisterResourceOutputsRequest(urn, outputs_struct)

        @test pb_request.urn == urn
        @test pb_request.outputs !== nothing
        @test pb_request.outputs isa Pulumi.pulumirpc.google.protobuf.Struct
    end

    @testset "Output serialization types" begin
        # Test various output types serialize correctly
        outputs = Dict{String, Any}(
            "stringOutput" => "value",
            "numberOutput" => 123.45,
            "intOutput" => 42,
            "boolOutput" => true,
            "nullOutput" => nothing,
            "arrayOutput" => [1, 2, 3],
            "nestedOutput" => Dict{String, Any}(
                "inner" => "innerValue"
            )
        )

        struct_val = Pulumi.dict_to_struct(outputs)
        result = Pulumi.struct_to_dict(struct_val)

        @test result["stringOutput"] == "value"
        @test result["numberOutput"] == 123.45
        @test result["intOutput"] == 42.0  # Numbers become Float64
        @test result["boolOutput"] == true
        @test result["nullOutput"] === nothing
        @test result["arrayOutput"] == [1.0, 2.0, 3.0]  # Numbers become Float64
        @test result["nestedOutput"]["inner"] == "innerValue"
    end

    @testset "Empty outputs" begin
        # Contract: SHOULD accept empty outputs dict
        outputs = Dict{String, Any}()
        struct_val = Pulumi.dict_to_struct(outputs)

        @test isempty(struct_val.fields)
    end

    @testset "URN format" begin
        # Contract: URN should follow Pulumi URN format
        # urn:pulumi:{stack}::{project}::{type}::{name}
        urn = "urn:pulumi:dev::myproject::custom:component:MyComponent::instance1"
        @test startswith(urn, "urn:pulumi:")
        @test occursin("::", urn)
    end
end
