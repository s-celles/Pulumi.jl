# Contract tests for Engine Client
# These tests verify compliance with the Pulumi Engine gRPC contract

@testset "Engine Client Contract" begin
    @testset "Log RPC" begin
        # T032: Contract test for EngineClient.log_rpc()
        @testset "Log request format" begin
            # Verify EngineClient exists and has required structure
            @test isdefined(Pulumi, :EngineClient)

            # Create client
            client = EngineClient("localhost:50051")
            @test client isa EngineClient
            @test client.address == "localhost:50051"
            @test !client.connected
            @test client.channel === nothing
        end

        @testset "Silent failure on disconnected" begin
            # Contract: MUST NOT throw on failure (logging is best-effort)
            client = EngineClient("localhost:50051")
            @test !client.connected

            # log_rpc should not throw when disconnected
            result = log_rpc(client, Dict{String,Any}(
                "severity" => 2,
                "message" => "test",
                "urn" => "",
                "streamId" => 0,
                "ephemeral" => false
            ))
            @test result === nothing
        end
    end

    @testset "Log Level Mapping" begin
        # T033: Contract test for log level mapping
        @testset "LogSeverity values" begin
            # Verify GRPCLogSeverity values match protobuf spec
            @test GRPCLogSeverity.DEBUG == 1
            @test GRPCLogSeverity.INFO == 2
            @test GRPCLogSeverity.WARNING == 3
            @test GRPCLogSeverity.ERROR == 4
        end

        @testset "Log severity conversion" begin
            # Test string to int conversion
            @test log_severity_to_grpc("debug") == 1
            @test log_severity_to_grpc("info") == 2
            @test log_severity_to_grpc("warning") == 3
            @test log_severity_to_grpc("error") == 4

            # Test default/unknown
            @test log_severity_to_grpc("unknown") == 2  # Default to INFO
        end
    end

    @testset "GetRootResource RPC" begin
        @testset "Throws when disconnected" begin
            client = EngineClient("localhost:50051")
            @test !client.connected

            # get_root_resource_rpc should throw when disconnected
            @test_throws GRPCError get_root_resource_rpc(client)
        end
    end

    @testset "Connection Management" begin
        @testset "Connect and disconnect" begin
            client = EngineClient("localhost:50051")

            # Connect
            connect!(client)
            @test client.connected

            # Disconnect
            disconnect!(client)
            @test !client.connected
        end

        @testset "is_connected helper" begin
            client = EngineClient("localhost:50051")
            @test !is_connected(client)

            connect!(client)
            @test is_connected(client)

            disconnect!(client)
            @test !is_connected(client)
        end
    end
end
