"""
Logging functions for Pulumi programs.

Per data-model.md:
- Log messages sent to engine via gRPC
- Support for severity levels: DEBUG, INFO, WARNING, ERROR
- Ephemeral messages for progress updates
"""

"""
    log(severity::LogSeverity.T, message::String;
        resource::Union{Resource, Nothing}=nothing,
        stream_id::Int=0,
        ephemeral::Bool=false)

Send a log message to the Pulumi engine.

# Arguments
- `severity::LogSeverity.T`: Log level (DEBUG, INFO, WARNING, ERROR)
- `message::String`: Log message text
- `resource::Union{Resource, Nothing}`: Associated resource (optional)
- `stream_id::Int`: Stream ID for grouping related messages
- `ephemeral::Bool`: If true, message is temporary (progress updates)
"""
function log(
    severity::LogSeverity.T,
    message::String;
    resource::Union{Resource, Nothing} = nothing,
    stream_id::Int = 0,
    ephemeral::Bool = false
)
    ctx = get_context()

    request = Dict{String, Any}(
        "severity" => severity,
        "message" => message,
        "urn" => resource !== nothing ? get_urn(resource) : "",
        "streamId" => stream_id,
        "ephemeral" => ephemeral
    )

    log_rpc(ctx._engine, request)
end

"""
    log_debug(message::String; kwargs...)

Log a debug message.

# Arguments
- `message::String`: Debug message
- `kwargs...`: Additional options (resource, stream_id, ephemeral)

# Example
```julia
log_debug("Processing resource inputs")
```
"""
function log_debug(message::String; kwargs...)
    log(LogSeverity.DEBUG, message; kwargs...)
end

"""
    log_info(message::String; kwargs...)

Log an informational message.

# Arguments
- `message::String`: Info message
- `kwargs...`: Additional options (resource, stream_id, ephemeral)

# Example
```julia
log_info("Created bucket successfully")
```
"""
function log_info(message::String; kwargs...)
    log(LogSeverity.INFO, message; kwargs...)
end

"""
    log_warn(message::String; kwargs...)

Log a warning message.

# Arguments
- `message::String`: Warning message
- `kwargs...`: Additional options (resource, stream_id, ephemeral)

# Example
```julia
log_warn("Deprecated property used")
```
"""
function log_warn(message::String; kwargs...)
    log(LogSeverity.WARNING, message; kwargs...)
end

"""
    log_error(message::String; kwargs...)

Log an error message.

# Arguments
- `message::String`: Error message
- `kwargs...`: Additional options (resource, stream_id, ephemeral)

# Example
```julia
log_error("Failed to create resource: permission denied")
```
"""
function log_error(message::String; kwargs...)
    log(LogSeverity.ERROR, message; kwargs...)
end

"""
    with_log_stream(f::Function; resource::Union{Resource, Nothing}=nothing)

Execute a function with a dedicated log stream for grouping related messages.

# Arguments
- `f::Function`: Function that receives stream_id as argument
- `resource::Union{Resource, Nothing}`: Associated resource

# Example
```julia
with_log_stream(resource=my_bucket) do stream_id
    log_info("Step 1...", stream_id=stream_id)
    log_info("Step 2...", stream_id=stream_id)
end
```
"""
function with_log_stream(f::Function; resource::Union{Resource, Nothing} = nothing)
    stream_id = abs(rand(Int32))
    f(stream_id)
end
