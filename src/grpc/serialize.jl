"""
Property serialization/deserialization for gRPC communication.

Per constitution's gRPC Protocol Fidelity principle:
- Protocol Buffers serialization/deserialization using ProtoBuf.jl
- Proper secret encoding with signature markers
"""

using JSON3

# Secret signature marker per Pulumi spec
const SECRET_SIG = "4dabf18193072939515e22adb298388d"
const RESOURCE_SIG = "5cf8f73096256a8f31e491e813e4eb8e"
const OUTPUT_SIG = "d0e6a833031e9bbcd3f4e8bde6ca49a4"

"""
    serialize_property(value::Any) -> Any

Serialize a Julia value for gRPC transmission.
Handles basic types, collections, and Output values.
"""
function serialize_property(value::Any)
    if value isa String
        return value
    elseif value isa Number
        return Float64(value)
    elseif value isa Bool
        return value
    elseif value isa Nothing
        return nothing
    elseif value isa Dict
        return serialize_struct(value)
    elseif value isa Vector || value isa Tuple
        return serialize_list(value)
    elseif value isa Output
        return serialize_output(value)
    else
        # Fallback: convert to string
        return string(value)
    end
end

"""
    serialize_struct(d::Dict) -> Dict{String, Any}

Serialize a dictionary for gRPC transmission.
"""
function serialize_struct(d::Dict)::Dict{String, Any}
    result = Dict{String, Any}()
    sizehint!(result, length(d))
    for (k, v) in d
        result[string(k)] = serialize_property(v)
    end
    return result
end

"""
    serialize_list(v::Union{Vector, Tuple}) -> Vector{Any}

Serialize a list/tuple for gRPC transmission.
"""
function serialize_list(v::Union{Vector, Tuple})::Vector{Any}
    result = Vector{Any}(undef, length(v))
    for (i, item) in enumerate(v)
        result[i] = serialize_property(item)
    end
    return result
end

"""
    serialize_output(output::Output) -> Any

Serialize an Output for gRPC transmission.
Handles secret marking and unknown values.
"""
function serialize_output(output::Output)
    if output.is_secret
        # Wrap in secret envelope
        return Dict{String, Any}(
            SECRET_SIG => "1",
            "value" => output.is_known ? serialize_property(output.value) : nothing
        )
    elseif output.is_known
        # Return the serialized value directly (not wrapped in a Dict)
        return serialize_property(output.value)
    else
        # Unknown value - return empty dict marker
        return Dict{String, Any}()
    end
end

"""
    deserialize_property(value::Any, ::Type{T}) -> T

Deserialize a value from gRPC response to Julia type.
"""
function deserialize_property(value::Any, ::Type{T}) where T
    if value === nothing
        return nothing
    elseif T === String && value isa AbstractString
        return String(value)
    elseif T <: Number && value isa Number
        return T(value)
    elseif T === Bool && value isa Bool
        return value
    elseif T <: Dict && value isa Dict
        return deserialize_struct(value, T)
    elseif T <: Vector && value isa Vector
        return deserialize_list(value, eltype(T))
    else
        # Try to convert
        return convert(T, value)
    end
end

function deserialize_property(value::Any)
    # Auto-detect type
    if value === nothing
        return nothing
    elseif value isa AbstractString
        return String(value)
    elseif value isa Number
        return value
    elseif value isa Bool
        return value
    elseif value isa Dict
        return deserialize_struct(value)
    elseif value isa Vector
        return [deserialize_property(v) for v in value]
    else
        return value
    end
end

"""
    deserialize_struct(d::Dict) -> Dict{String, Any}

Deserialize a dictionary from gRPC response.
Detects and unwraps secret envelopes.
"""
function deserialize_struct(d::Dict)::Dict{String, Any}
    # Check for secret envelope
    if haskey(d, SECRET_SIG)
        # This is a secret - the actual value is in "value" key
        inner = get(d, "value", nothing)
        return Dict{String, Any}("__secret" => true, "value" => deserialize_property(inner))
    end

    result = Dict{String, Any}()
    sizehint!(result, length(d))
    for (k, v) in d
        result[String(k)] = deserialize_property(v)
    end
    return result
end

function deserialize_struct(d::Dict, ::Type{Dict{K, V}}) where {K, V}
    result = Dict{K, V}()
    sizehint!(result, length(d))
    for (k, v) in d
        result[convert(K, k)] = deserialize_property(v, V)
    end
    return result
end

"""
    deserialize_list(v::Vector, ::Type{T}) -> Vector{T}

Deserialize a list from gRPC response.
"""
function deserialize_list(v::Vector, ::Type{T}) where T
    return T[deserialize_property(item, T) for item in v]
end

"""
    is_secret_value(d::Dict) -> Bool

Check if a deserialized dict represents a secret value.
"""
function is_secret_value(d::Dict)::Bool
    haskey(d, SECRET_SIG) || get(d, "__secret", false)
end

"""
    unwrap_secret(d::Dict) -> Any

Unwrap a secret envelope to get the actual value.
"""
function unwrap_secret(d::Dict)
    if haskey(d, SECRET_SIG)
        return get(d, "value", nothing)
    elseif haskey(d, "__secret")
        return get(d, "value", nothing)
    else
        return d
    end
end
