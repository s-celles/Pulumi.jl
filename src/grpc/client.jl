"""
gRPC client wrappers for Pulumi engine communication.

Per constitution's gRPC Protocol Fidelity principle:
- ResourceMonitor client: RegisterResource, RegisterResourceOutputs, ReadResource, Invoke, Call
- Engine client: Logging and engine communication
"""

# Note: Actual gRPC implementation requires ProtoBuf.jl generated types
# This is a mock implementation for the SDK structure

"""
    MonitorClient

gRPC client for the ResourceMonitor service.
Handles resource registration and provider invocation.
"""
mutable struct MonitorClient
    address::String
    connected::Bool
    # In real implementation: channel, stub, etc.

    MonitorClient(address::String) = new(address, false)
end

"""
    connect!(client::MonitorClient)

Establish connection to the ResourceMonitor service.
"""
function connect!(client::MonitorClient)
    # TODO: Implement actual gRPC connection
    client.connected = true
    return client
end

"""
    disconnect!(client::MonitorClient)

Close connection to the ResourceMonitor service.
"""
function disconnect!(client::MonitorClient)
    client.connected = false
    return client
end

"""
    is_connected(client::MonitorClient) -> Bool

Check if the client is connected.
"""
is_connected(client::MonitorClient) = client.connected

"""
    register_resource_rpc(client::MonitorClient, request::Dict) -> Dict

Send RegisterResource RPC to the monitor.
"""
function register_resource_rpc(client::MonitorClient, request::Dict)::Dict
    if !client.connected
        throw(GRPCError(14, "Client not connected to ResourceMonitor", true))
    end

    with_retry() do
        # TODO: Implement actual gRPC call
        # For now, return mock response
        Dict{String, Any}(
            "urn" => "urn:pulumi:stack::project::$(get(request, "type", "unknown"))::$(get(request, "name", "unknown"))",
            "id" => string(uuid4()),
            "object" => Dict{String, Any}(),
            "stable" => true,
            "stables" => String[]
        )
    end
end

"""
    register_resource_outputs_rpc(client::MonitorClient, request::Dict)

Send RegisterResourceOutputs RPC to the monitor.
"""
function register_resource_outputs_rpc(client::MonitorClient, request::Dict)
    if !client.connected
        throw(GRPCError(14, "Client not connected to ResourceMonitor", true))
    end

    with_retry() do
        # TODO: Implement actual gRPC call
        nothing
    end
end

"""
    invoke_rpc(client::MonitorClient, request::Dict) -> Dict

Send Invoke RPC to the monitor.
"""
function invoke_rpc(client::MonitorClient, request::Dict)::Dict
    if !client.connected
        throw(GRPCError(14, "Client not connected to ResourceMonitor", true))
    end

    with_retry() do
        # TODO: Implement actual gRPC call
        Dict{String, Any}(
            "return" => Dict{String, Any}(),
            "failures" => []
        )
    end
end

"""
    read_resource_rpc(client::MonitorClient, request::Dict) -> Dict

Send ReadResource RPC to the monitor.
"""
function read_resource_rpc(client::MonitorClient, request::Dict)::Dict
    if !client.connected
        throw(GRPCError(14, "Client not connected to ResourceMonitor", true))
    end

    with_retry() do
        # TODO: Implement actual gRPC call
        Dict{String, Any}(
            "urn" => "",
            "properties" => Dict{String, Any}()
        )
    end
end

"""
    supports_feature_rpc(client::MonitorClient, feature::String) -> Bool

Check if the engine supports a specific feature.
"""
function supports_feature_rpc(client::MonitorClient, feature::String)::Bool
    if !client.connected
        return false
    end

    with_retry() do
        # TODO: Implement actual gRPC call
        true  # Assume features are supported
    end
end

"""
    EngineClient

gRPC client for the Engine service.
Handles logging and root resource access.
"""
mutable struct EngineClient
    address::String
    connected::Bool

    EngineClient(address::String) = new(address, false)
end

"""
    connect!(client::EngineClient)

Establish connection to the Engine service.
"""
function connect!(client::EngineClient)
    # TODO: Implement actual gRPC connection
    client.connected = true
    return client
end

"""
    disconnect!(client::EngineClient)

Close connection to the Engine service.
"""
function disconnect!(client::EngineClient)
    client.connected = false
    return client
end

"""
    is_connected(client::EngineClient) -> Bool

Check if the client is connected.
"""
is_connected(client::EngineClient) = client.connected

"""
    log_rpc(client::EngineClient, request::Dict)

Send Log RPC to the engine.
"""
function log_rpc(client::EngineClient, request::Dict)
    if !client.connected
        # Silently fail for logging - don't throw
        return nothing
    end

    # TODO: Implement actual gRPC call
    nothing
end

"""
    get_root_resource_rpc(client::EngineClient) -> String

Get the root stack resource URN.
"""
function get_root_resource_rpc(client::EngineClient)::String
    if !client.connected
        throw(GRPCError(14, "Client not connected to Engine", true))
    end

    with_retry() do
        # TODO: Implement actual gRPC call
        ""
    end
end
