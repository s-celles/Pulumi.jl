"""
gRPC client wrappers for Pulumi engine communication.

Per constitution's gRPC Protocol Fidelity principle:
- ResourceMonitor client: RegisterResource, RegisterResourceOutputs, ReadResource, Invoke, Call
- Engine client: Logging and engine communication
"""

using gRPCClient
using ProtoBuf: OneOf

# Import proto types (included at Pulumi module level)
using .pulumirpc: RegisterResourceRequest, RegisterResourceResponse
using .pulumirpc: RegisterResourceOutputsRequest
using .pulumirpc: ReadResourceRequest, ReadResourceResponse
using .pulumirpc: ResourceInvokeRequest, InvokeResponse
using .pulumirpc: SupportsFeatureRequest, SupportsFeatureResponse
using .pulumirpc: LogRequest
using .pulumirpc: GetRootResourceRequest, GetRootResourceResponse
using .pulumirpc.google.protobuf: Empty, Struct, Value, ListValue, NullValue

# Alias the protobuf LogSeverity to avoid conflict with errors.jl LogSeverity
const PBLogSeverity = pulumirpc.LogSeverity

# ============================================================================
# Protobuf Conversion Helpers
# ============================================================================

"""
    dict_to_struct(d::Dict) -> Struct

Convert a Julia Dict to a google.protobuf.Struct for gRPC transmission.
"""
function dict_to_struct(d::Dict)::Struct
    fields = Dict{String, Value}()
    for (k, v) in d
        fields[string(k)] = julia_to_value(v)
    end
    return Struct(fields)
end

"""
    julia_to_value(v) -> Value

Convert a Julia value to a google.protobuf.Value.
"""
function julia_to_value(v)::Value
    if v === nothing
        return Value(OneOf(:null_value, NullValue.NULL_VALUE))
    elseif v isa Bool
        return Value(OneOf(:bool_value, v))
    elseif v isa Number
        return Value(OneOf(:number_value, Float64(v)))
    elseif v isa AbstractString
        return Value(OneOf(:string_value, String(v)))
    elseif v isa Dict
        return Value(OneOf(:struct_value, dict_to_struct(v)))
    elseif v isa AbstractVector || v isa Tuple
        values = [julia_to_value(item) for item in v]
        return Value(OneOf(:list_value, ListValue(values)))
    else
        # Fallback: convert to string
        return Value(OneOf(:string_value, string(v)))
    end
end

"""
    struct_to_dict(s::Struct) -> Dict{String, Any}

Convert a google.protobuf.Struct to a Julia Dict.
"""
function struct_to_dict(s::Union{Nothing, Struct})::Dict{String, Any}
    s === nothing && return Dict{String, Any}()
    result = Dict{String, Any}()
    for (k, v) in s.fields
        result[k] = value_to_julia(v)
    end
    return result
end

"""
    value_to_julia(v::Value) -> Any

Convert a google.protobuf.Value to a Julia value.
"""
function value_to_julia(v::Value)
    v.kind === nothing && return nothing
    kind = v.kind
    if kind.name === :null_value
        return nothing
    elseif kind.name === :bool_value
        return kind[]::Bool
    elseif kind.name === :number_value
        return kind[]::Float64
    elseif kind.name === :string_value
        return kind[]::String
    elseif kind.name === :struct_value
        return struct_to_dict(kind[]::Struct)
    elseif kind.name === :list_value
        list = kind[]::ListValue
        return [value_to_julia(item) for item in list.values]
    else
        return nothing
    end
end

# ============================================================================
# GRPCChannel placeholder (for backwards compatibility)
# ============================================================================

"""
    GRPCChannel

Placeholder type for gRPC channel connection.
Actual connection is managed by gRPCClient internally.
"""
struct GRPCChannel
    address::String
end

# ============================================================================
# MonitorClient
# ============================================================================

"""
    MonitorClient

gRPC client for the ResourceMonitor service.
Handles resource registration and provider invocation.
"""
mutable struct MonitorClient
    address::String
    channel::Union{Nothing, GRPCChannel}
    connected::Bool
    # gRPC service clients (created on connect)
    _register_resource_client::Any
    _register_outputs_client::Any
    _read_resource_client::Any
    _invoke_client::Any
    _supports_feature_client::Any

    MonitorClient(address::String) = new(address, nothing, false, nothing, nothing, nothing, nothing, nothing)
end

"""
    connect!(client::MonitorClient)

Establish connection to the ResourceMonitor service.
"""
function connect!(client::MonitorClient)
    if client.connected
        return client
    end

    # Initialize gRPC (safe to call multiple times)
    gRPCClient.grpc_init()

    # Parse address (format: "host:port")
    host, port = _parse_address(client.address)

    # Create gRPC service clients for each RPC method
    # Using gRPCServiceClient with proper type parameters
    client._register_resource_client = gRPCClient.gRPCServiceClient{
        RegisterResourceRequest, false, RegisterResourceResponse, false
    }(host, port, "/pulumirpc.ResourceMonitor/RegisterResource")

    client._register_outputs_client = gRPCClient.gRPCServiceClient{
        RegisterResourceOutputsRequest, false, Empty, false
    }(host, port, "/pulumirpc.ResourceMonitor/RegisterResourceOutputs")

    client._read_resource_client = gRPCClient.gRPCServiceClient{
        ReadResourceRequest, false, ReadResourceResponse, false
    }(host, port, "/pulumirpc.ResourceMonitor/ReadResource")

    client._invoke_client = gRPCClient.gRPCServiceClient{
        ResourceInvokeRequest, false, InvokeResponse, false
    }(host, port, "/pulumirpc.ResourceMonitor/Invoke")

    client._supports_feature_client = gRPCClient.gRPCServiceClient{
        SupportsFeatureRequest, false, SupportsFeatureResponse, false
    }(host, port, "/pulumirpc.ResourceMonitor/SupportsFeature")

    client.channel = GRPCChannel(client.address)
    client.connected = true
    return client
end

"""
    disconnect!(client::MonitorClient)

Close connection to the ResourceMonitor service.
"""
function disconnect!(client::MonitorClient)
    client._register_resource_client = nothing
    client._register_outputs_client = nothing
    client._read_resource_client = nothing
    client._invoke_client = nothing
    client._supports_feature_client = nothing
    client.channel = nothing
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
        # Build protobuf request
        pb_request = _build_register_resource_request(request)

        # Make gRPC call
        pb_response = gRPCClient.grpc_sync_request(client._register_resource_client, pb_request)

        # Convert response to Dict
        Dict{String, Any}(
            "urn" => pb_response.urn,
            "id" => pb_response.id,
            "object" => struct_to_dict(pb_response.object),
            "stable" => pb_response.stable,
            "stables" => pb_response.stables
        )
    end
end

"""
    _build_register_resource_request(request::Dict) -> RegisterResourceRequest

Build a RegisterResourceRequest protobuf message from a Dict.
"""
function _build_register_resource_request(request::Dict)::RegisterResourceRequest
    # Extract fields with defaults
    type_val = get(request, "type", "")
    name_val = get(request, "name", "")
    parent_val = get(request, "parent", "")
    custom_val = get(request, "custom", true)
    object_val = get(request, "object", nothing)
    protect_val = get(request, "protect", false)
    dependencies_val = get(request, "dependencies", String[])
    provider_val = get(request, "provider", "")

    # Convert property dependencies
    prop_deps_raw = get(request, "propertyDependencies", Dict{String, Any}())
    prop_deps = Dict{String, pulumirpc.var"RegisterResourceRequest.PropertyDependencies"}()
    for (k, v) in prop_deps_raw
        urns = v isa Vector ? String[string(u) for u in v] : String[]
        prop_deps[string(k)] = pulumirpc.var"RegisterResourceRequest.PropertyDependencies"(urns)
    end

    # Build the request with all fields
    RegisterResourceRequest(
        type_val,                                           # type
        name_val,                                           # name
        parent_val,                                         # parent
        custom_val,                                         # custom
        object_val !== nothing ? dict_to_struct(object_val) : nothing, # object
        protect_val,                                        # protect
        dependencies_val,                                   # dependencies
        provider_val,                                       # provider
        prop_deps,                                          # propertyDependencies
        get(request, "deleteBeforeReplace", false),         # deleteBeforeReplace
        get(request, "version", ""),                        # version
        get(request, "ignoreChanges", String[]),            # ignoreChanges
        get(request, "acceptSecrets", true),                # acceptSecrets
        get(request, "additionalSecretOutputs", String[]),  # additionalSecretOutputs
        String[],                                           # aliasURNs (deprecated)
        get(request, "importId", ""),                       # importId
        nothing,                                            # customTimeouts
        false,                                              # deleteBeforeReplaceDefined
        true,                                               # supportsPartialValues
        false,                                              # remote
        get(request, "acceptResources", true),              # acceptResources
        Dict{String, String}(),                             # providers
        get(request, "replaceOnChanges", String[]),         # replaceOnChanges
        "",                                                 # pluginDownloadURL
        Dict{String, Vector{UInt8}}(),                      # pluginChecksums
        get(request, "retainOnDelete", false),              # retainOnDelete
        get(request, "aliases", pulumirpc.Alias[]),         # aliases
        get(request, "deletedWith", ""),                    # deletedWith
        String[],                                           # replace_with
        nothing,                                            # replacement_trigger
        true,                                               # aliasSpecs
        nothing,                                            # sourcePosition
        nothing,                                            # stackTrace
        "",                                                 # parentStackTraceHandle
        pulumirpc.Callback[],                               # transforms
        true,                                               # supportsResultReporting
        "",                                                 # packageRef
        nothing,                                            # hooks
        String[]                                            # hideDiffs
    )
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
        urn = get(request, "urn", "")
        outputs = get(request, "outputs", Dict{String, Any}())

        pb_request = RegisterResourceOutputsRequest(
            urn,
            !isempty(outputs) ? dict_to_struct(outputs) : nothing
        )

        gRPCClient.grpc_sync_request(client._register_outputs_client, pb_request)
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
        tok = get(request, "tok", "")
        args = get(request, "args", Dict{String, Any}())
        provider = get(request, "provider", "")
        version = get(request, "version", "")

        pb_request = ResourceInvokeRequest(
            tok,
            !isempty(args) ? dict_to_struct(args) : nothing,
            provider,
            version,
            true,  # acceptResources
            "",    # pluginDownloadURL
            Dict{String, Vector{UInt8}}(),  # pluginChecksums
            nothing,  # sourcePosition
            nothing,  # stackTrace
            "",    # parentStackTraceHandle
            ""     # packageRef
        )

        pb_response = gRPCClient.grpc_sync_request(client._invoke_client, pb_request)

        # Convert failures
        failures = []
        if pb_response.failures !== nothing
            for f in pb_response.failures
                push!(failures, Dict{String, Any}(
                    "property" => f.property,
                    "reason" => f.reason
                ))
            end
        end

        Dict{String, Any}(
            "return" => struct_to_dict(pb_response.var"#return"),
            "failures" => failures
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
        id = get(request, "id", "")
        type_val = get(request, "type", "")
        name = get(request, "name", "")
        parent = get(request, "parent", "")
        properties = get(request, "properties", Dict{String, Any}())
        dependencies = get(request, "dependencies", String[])
        provider = get(request, "provider", "")
        version = get(request, "version", "")

        pb_request = ReadResourceRequest(
            id,
            type_val,
            name,
            parent,
            !isempty(properties) ? dict_to_struct(properties) : nothing,
            dependencies,
            provider,
            version,
            true,   # acceptSecrets
            String[], # additionalSecretOutputs
            String[], # aliasURNs (deprecated)
            true,   # acceptResources
            "",     # pluginDownloadURL
            Dict{String, Vector{UInt8}}(), # pluginChecksums
            nothing, # sourcePosition
            "",     # packageRef
            Dict{String, pulumirpc.var"ReadResourceRequest.PropertyDependencies"}() # propertyDependencies
        )

        pb_response = gRPCClient.grpc_sync_request(client._read_resource_client, pb_request)

        Dict{String, Any}(
            "urn" => pb_response.urn,
            "properties" => struct_to_dict(pb_response.properties)
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
        pb_request = SupportsFeatureRequest(feature)
        pb_response = gRPCClient.grpc_sync_request(client._supports_feature_client, pb_request)
        pb_response.hasSupport
    end
end

# ============================================================================
# EngineClient
# ============================================================================

"""
    EngineClient

gRPC client for the Engine service.
Handles logging and root resource access.
"""
mutable struct EngineClient
    address::String
    channel::Union{Nothing, GRPCChannel}
    connected::Bool
    # gRPC service clients
    _log_client::Any
    _get_root_resource_client::Any

    EngineClient(address::String) = new(address, nothing, false, nothing, nothing)
end

"""
    connect!(client::EngineClient)

Establish connection to the Engine service.
"""
function connect!(client::EngineClient)
    if client.connected
        return client
    end

    # Initialize gRPC (safe to call multiple times)
    gRPCClient.grpc_init()

    # Parse address
    host, port = _parse_address(client.address)

    # Create gRPC service clients
    client._log_client = gRPCClient.gRPCServiceClient{
        LogRequest, false, Empty, false
    }(host, port, "/pulumirpc.Engine/Log")

    client._get_root_resource_client = gRPCClient.gRPCServiceClient{
        GetRootResourceRequest, false, GetRootResourceResponse, false
    }(host, port, "/pulumirpc.Engine/GetRootResource")

    client.channel = GRPCChannel(client.address)
    client.connected = true
    return client
end

"""
    disconnect!(client::EngineClient)

Close connection to the Engine service.
"""
function disconnect!(client::EngineClient)
    client._log_client = nothing
    client._get_root_resource_client = nothing
    client.channel = nothing
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

    try
        severity_val = get(request, "severity", 2)
        message = get(request, "message", "")
        urn = get(request, "urn", "")
        stream_id = get(request, "streamId", 0)
        ephemeral = get(request, "ephemeral", false)

        # Map severity Int to PBLogSeverity enum
        severity = if severity_val == 1
            PBLogSeverity.DEBUG
        elseif severity_val == 2
            PBLogSeverity.INFO
        elseif severity_val == 3
            PBLogSeverity.WARNING
        elseif severity_val == 4
            PBLogSeverity.ERROR
        else
            PBLogSeverity.INFO
        end

        pb_request = LogRequest(
            severity,
            message,
            urn,
            Int32(stream_id),
            ephemeral
        )

        gRPCClient.grpc_sync_request(client._log_client, pb_request)
    catch
        # Silently fail for logging
    end
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
        pb_request = GetRootResourceRequest()
        pb_response = gRPCClient.grpc_sync_request(client._get_root_resource_client, pb_request)
        pb_response.urn
    end
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
    _parse_address(address::String) -> Tuple{String, Int}

Parse a gRPC address string (host:port) into host and port components.
"""
function _parse_address(address::String)
    # Remove any protocol prefix if present
    addr = replace(address, r"^(http://|https://|grpc://)" => "")

    parts = split(addr, ":")
    if length(parts) >= 2
        host = parts[1]
        port = parse(Int, parts[end])
        return (host, port)
    else
        # Default port
        return (addr, 50051)
    end
end
