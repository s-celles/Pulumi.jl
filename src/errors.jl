"""
Pulumi error type hierarchy.

Per constitution's Error Handling requirements:
- Actionable error messages (what failed, why, how to fix)
- Custom exception hierarchy for different error types
"""

"""
    PulumiError <: Exception

Abstract base type for all Pulumi errors.
"""
abstract type PulumiError <: Exception end

"""
    ResourceError <: PulumiError

Error during resource registration or management.

# Fields
- `urn::String`: Resource URN (if known)
- `message::String`: Error description
- `cause::Union{Exception, Nothing}`: Underlying exception
"""
struct ResourceError <: PulumiError
    urn::String
    message::String
    cause::Union{Exception, Nothing}
end

ResourceError(message::String) = ResourceError("", message, nothing)
ResourceError(urn::String, message::String) = ResourceError(urn, message, nothing)

function Base.showerror(io::IO, e::ResourceError)
    print(io, "ResourceError: ", e.message)
    if !isempty(e.urn)
        print(io, "\n  Resource: ", e.urn)
    end
    if e.cause !== nothing
        print(io, "\n  Caused by: ")
        showerror(io, e.cause)
    end
end

"""
    GRPCError <: PulumiError

gRPC communication error with the Pulumi engine.

# Fields
- `code::Int`: gRPC status code
- `message::String`: Error message
- `retryable::Bool`: Whether the operation can be retried
"""
struct GRPCError <: PulumiError
    code::Int
    message::String
    retryable::Bool
end

GRPCError(code::Int, message::String) = GRPCError(code, message, code == 14)  # UNAVAILABLE is retryable

function Base.showerror(io::IO, e::GRPCError)
    print(io, "GRPCError (code ", e.code, "): ", e.message)
    if e.retryable
        print(io, "\n  This error is retryable")
    end
end

"""
    ConfigMissingError <: PulumiError

Missing required configuration key.

# Fields
- `key::String`: Configuration key name
- `namespace::String`: Configuration namespace (usually project name)
"""
struct ConfigMissingError <: PulumiError
    key::String
    namespace::String
end

function Base.showerror(io::IO, e::ConfigMissingError)
    full_key = isempty(e.namespace) ? e.key : "$(e.namespace):$(e.key)"
    print(io, "ConfigMissingError: Missing required configuration key '", full_key, "'")
    print(io, "\n  Set it with: pulumi config set ", full_key, " <value>")
end

"""
    DependencyError <: PulumiError

Error in resource dependency resolution.

# Fields
- `message::String`: Error description
- `resources::Vector{String}`: URNs involved in the error
"""
struct DependencyError <: PulumiError
    message::String
    resources::Vector{String}
end

DependencyError(message::String) = DependencyError(message, String[])

function Base.showerror(io::IO, e::DependencyError)
    print(io, "DependencyError: ", e.message)
    if !isempty(e.resources)
        print(io, "\n  Resources involved:")
        for urn in e.resources
            print(io, "\n    - ", urn)
        end
    end
end

# ============================================================================
# gRPC Status Codes
# ============================================================================

"""
    GRPCStatusCode

gRPC status codes for protocol-level error communication.
Maps to the standard gRPC status codes.
"""
module GRPCStatusCode
    const OK = 0
    const CANCELLED = 1
    const UNKNOWN = 2
    const INVALID_ARGUMENT = 3
    const DEADLINE_EXCEEDED = 4
    const NOT_FOUND = 5
    const ALREADY_EXISTS = 6
    const PERMISSION_DENIED = 7
    const RESOURCE_EXHAUSTED = 8
    const FAILED_PRECONDITION = 9
    const ABORTED = 10
    const OUT_OF_RANGE = 11
    const UNIMPLEMENTED = 12
    const INTERNAL = 13
    const UNAVAILABLE = 14
    const DATA_LOSS = 15
    const UNAUTHENTICATED = 16
end

"""
    exception_to_grpc_code(e::Exception) -> Int

Map a Julia exception to a gRPC status code.
"""
function exception_to_grpc_code(e::Exception)::Int
    if e isa ArgumentError
        return GRPCStatusCode.INVALID_ARGUMENT
    elseif e isa KeyError
        return GRPCStatusCode.NOT_FOUND
    elseif e isa MethodError
        return GRPCStatusCode.UNIMPLEMENTED
    elseif e isa InterruptException
        return GRPCStatusCode.CANCELLED
    elseif e isa OutOfMemoryError
        return GRPCStatusCode.RESOURCE_EXHAUSTED
    elseif e isa GRPCError
        return e.code
    else
        return GRPCStatusCode.INTERNAL
    end
end

"""
    is_retryable_grpc_code(code::Int) -> Bool

Check if a gRPC status code indicates a retryable error.
"""
function is_retryable_grpc_code(code::Int)::Bool
    code == GRPCStatusCode.UNAVAILABLE || code == GRPCStatusCode.RESOURCE_EXHAUSTED
end

"""
    GRPCLogSeverity

Log severity levels for gRPC Engine Log RPC.
These match the protobuf LogSeverity enum values.
"""
module GRPCLogSeverity
    const DEBUG = 1
    const INFO = 2
    const WARNING = 3
    const ERROR = 4
end

"""
    log_severity_to_grpc(severity::String) -> Int

Convert LogSeverity string to gRPC LogSeverity integer.
"""
function log_severity_to_grpc(severity::String)::Int
    if severity == "debug"
        return GRPCLogSeverity.DEBUG
    elseif severity == "info"
        return GRPCLogSeverity.INFO
    elseif severity == "warning"
        return GRPCLogSeverity.WARNING
    elseif severity == "error"
        return GRPCLogSeverity.ERROR
    else
        return GRPCLogSeverity.INFO  # Default
    end
end
