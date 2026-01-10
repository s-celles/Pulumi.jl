"""
Provider function invocation for Pulumi programs.

Per data-model.md:
- Invoke calls provider functions without creating resources
- Used for data lookups (e.g., aws:ec2:getAmi)
- Returns Output containing result
"""

"""
    invoke(token::String, args::Dict{String, Any};
           provider::Union{ProviderResource, Nothing}=nothing,
           version::Union{String, Nothing}=nothing) -> Output

Invoke a provider function and return the result.

# Arguments
- `token::String`: Function token (e.g., "aws:ec2/getAmi:getAmi")
- `args::Dict{String, Any}`: Function arguments

# Keyword Arguments
- `provider::Union{ProviderResource, Nothing}`: Explicit provider to use
- `version::Union{String, Nothing}`: Provider version constraint

# Returns
- `Output`: Output containing the function result

# Example
```julia
ami = invoke("aws:ec2/getAmi:getAmi", Dict(
    "mostRecent" => true,
    "owners" => ["amazon"],
    "filters" => [Dict("name" => "name", "values" => ["amzn2-ami-hvm-*"])]
))
```
"""
function invoke(
    token::String,
    args::Dict{String, Any};
    provider::Union{ProviderResource, Nothing} = nothing,
    version::Union{String, Nothing} = nothing
)::Output
    ctx = get_context()

    # Serialize arguments
    serialized_args = serialize_struct(args)

    # Collect dependencies from Output values in args
    deps = collect_dependencies(args)

    # Build request
    request = Dict{String, Any}(
        "tok" => token,
        "args" => serialized_args,
        "provider" => provider !== nothing ? get_urn(provider) : "",
        "acceptResources" => true
    )

    if version !== nothing
        request["version"] = version
    end

    # Send RPC
    try
        response = invoke_rpc(ctx._monitor, request)

        # Check for failures
        failures = get(response, "failures", [])
        if !isempty(failures)
            error_msg = join([f["reason"] for f in failures], "; ")
            throw(PulumiError("Invoke failed: $error_msg"))
        end

        # Deserialize result
        result = deserialize_struct(get(response, "return", Dict()))

        # Return as Output with dependencies
        Output(result; dependencies=deps)
    catch e
        if e isa GRPCError
            throw(PulumiError("Failed to invoke $token: $(e.message)"))
        end
        rethrow()
    end
end

"""
    invoke(token::String; kwargs...) -> Output

Invoke a provider function with keyword arguments.

# Example
```julia
ami = invoke("aws:ec2/getAmi:getAmi";
    mostRecent=true,
    owners=["amazon"]
)
```
"""
function invoke(token::String; kwargs...)::Output
    args = Dict{String, Any}(string(k) => v for (k, v) in kwargs)
    invoke(token, args)
end

"""
    call(token::String, args::Dict{String, Any}, resource::Resource;
         provider::Union{ProviderResource, Nothing}=nothing,
         version::Union{String, Nothing}=nothing) -> Output

Call a method on a resource.

# Arguments
- `token::String`: Method token
- `args::Dict{String, Any}`: Method arguments
- `resource::Resource`: Resource to call method on

# Keyword Arguments
- `provider::Union{ProviderResource, Nothing}`: Explicit provider to use
- `version::Union{String, Nothing}`: Provider version constraint

# Returns
- `Output`: Output containing the method result
"""
function call(
    token::String,
    args::Dict{String, Any},
    resource::Resource;
    provider::Union{ProviderResource, Nothing} = nothing,
    version::Union{String, Nothing} = nothing
)::Output
    ctx = get_context()

    # Serialize arguments
    serialized_args = serialize_struct(args)

    # Build request (similar to invoke but with resource context)
    request = Dict{String, Any}(
        "tok" => token,
        "args" => serialized_args,
        "provider" => provider !== nothing ? get_urn(provider) : "",
        "self" => get_urn(resource),
        "acceptResources" => true
    )

    if version !== nothing
        request["version"] = version
    end

    # Send RPC (uses same invoke endpoint)
    try
        response = invoke_rpc(ctx._monitor, request)

        # Check for failures
        failures = get(response, "failures", [])
        if !isempty(failures)
            error_msg = join([f["reason"] for f in failures], "; ")
            throw(PulumiError("Call failed: $error_msg"))
        end

        # Deserialize result
        result = deserialize_struct(get(response, "return", Dict()))

        # Return as Output with resource dependency
        Output(result; dependencies=[get_urn(resource)])
    catch e
        if e isa GRPCError
            throw(PulumiError("Failed to call $token: $(e.message)"))
        end
        rethrow()
    end
end
