"""
gRPC retry logic with exponential backoff.

Per constitution's Error Handling requirements:
- gRPC failures: Retry with exponential backoff (max 3 attempts: 0.2s, 0.4s, 0.8s)
"""

const MAX_RETRIES = 3
const RETRY_DELAYS = [0.2, 0.4, 0.8]  # seconds

"""
    with_retry(f::Function; max_retries=MAX_RETRIES, delays=RETRY_DELAYS)

Execute a function with automatic retry on retryable gRPC errors.

# Arguments
- `f::Function`: Function to execute (should return a value or throw)
- `max_retries::Int`: Maximum number of retry attempts
- `delays::Vector{Float64}`: Delay in seconds before each retry

# Returns
- The result of `f()` on success

# Throws
- `GRPCError`: If all retries are exhausted or error is not retryable
- Any other exception from `f()`

# Example
```julia
result = with_retry() do
    call_grpc_method(...)
end
```
"""
function with_retry(
    f::Function;
    max_retries::Int = MAX_RETRIES,
    delays::Vector{Float64} = RETRY_DELAYS
)
    last_error = nothing

    for attempt in 1:(max_retries + 1)
        try
            return f()
        catch e
            if e isa GRPCError && e.retryable && attempt <= max_retries
                last_error = e
                delay_idx = min(attempt, length(delays))
                sleep(delays[delay_idx])
                continue
            end
            rethrow()
        end
    end

    # Should not reach here, but just in case
    throw(last_error)
end

"""
    is_retryable_code(code::Int) -> Bool

Check if a gRPC status code indicates a retryable error.

Retryable codes:
- 14 (UNAVAILABLE): Service temporarily unavailable
- 8 (RESOURCE_EXHAUSTED): Rate limiting or quota exceeded
"""
function is_retryable_code(code::Int)::Bool
    code in [14, 8]  # UNAVAILABLE, RESOURCE_EXHAUSTED
end
