"""
Stack output exports for Pulumi programs.

Per data-model.md:
- Stack outputs are the final exported values from a Pulumi program
- Registered via RegisterResourceOutputs on the stack resource
- Can be marked as secrets
"""

# Global storage for stack outputs
const _STACK_OUTPUTS = Dict{String, Any}()
const _STACK_OUTPUT_LOCK = ReentrantLock()

"""
    export_value(name::String, value::Any)

Export a value as a stack output.

# Arguments
- `name::String`: Output name
- `value::Any`: Value to export (can be Output, primitive, or collection)

# Example
```julia
export_value("bucketName", bucket.name)
export_value("endpoint", "https://api.example.com")
```
"""
function export_value(name::String, value::Any)
    lock(_STACK_OUTPUT_LOCK) do
        _STACK_OUTPUTS[name] = value
    end
end

"""
    export_secret(name::String, value::Any)

Export a value as a secret stack output.

# Arguments
- `name::String`: Output name
- `value::Any`: Value to export (will be marked as secret)

# Example
```julia
export_secret("dbPassword", db_password)
```
"""
function export_secret(name::String, value::Any)
    # Wrap in secret Output if not already
    secret_value = if value isa Output
        if value.is_secret
            value
        else
            # Create a new secret Output with same value
            Output{eltype(typeof(value))}(
                value.id,
                value.value,
                true,  # is_secret
                value.is_known,
                value.dependencies
            )
        end
    else
        Output(value; is_secret=true)
    end

    lock(_STACK_OUTPUT_LOCK) do
        _STACK_OUTPUTS[name] = secret_value
    end
end

"""
    get_exports() -> Dict{String, Any}

Get all registered stack outputs.

# Returns
- `Dict{String, Any}`: Map of output names to values
"""
function get_exports()::Dict{String, Any}
    lock(_STACK_OUTPUT_LOCK) do
        copy(_STACK_OUTPUTS)
    end
end

"""
    clear_exports!()

Clear all registered stack outputs (for testing).
"""
function clear_exports!()
    lock(_STACK_OUTPUT_LOCK) do
        empty!(_STACK_OUTPUTS)
    end
end

"""
    register_stack_outputs()

Register all accumulated stack outputs with the engine.
Called automatically at program end.
"""
function register_stack_outputs()
    ctx = get_context()

    outputs = get_exports()
    if isempty(outputs)
        return
    end

    # Serialize outputs
    serialized = Dict{String, Any}()
    for (name, value) in outputs
        serialized[name] = serialize_property(value)
    end

    # Get root resource URN from engine
    root_urn = get_root_resource_rpc(ctx._engine)

    if !isempty(root_urn)
        request = Dict{String, Any}(
            "urn" => root_urn,
            "outputs" => serialized
        )

        register_resource_outputs_rpc(ctx._monitor, request)
    end
end

"""
    @export name = value

Macro for convenient stack output export.

# Example
```julia
@export bucketArn = bucket.arn
@export clusterEndpoint = cluster.endpoint
```
"""
macro export_output(expr)
    if expr.head != :(=)
        error("@export requires an assignment expression: @export name = value")
    end
    name = string(expr.args[1])
    value = expr.args[2]
    quote
        export_value($name, $(esc(value)))
    end
end
