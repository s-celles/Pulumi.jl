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
