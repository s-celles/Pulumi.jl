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

# URN of the root `pulumi:pulumi:Stack` resource, once registered.
const _ROOT_STACK_URN = Ref("")

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
    register_root_stack() -> String

Register the stack's root `pulumi:pulumi:Stack` resource and return its URN.

Every Pulumi language SDK registers this resource itself; the engine does not
create it. It is what stack outputs are attached to, and what the engine uses
as the default parent for the program's resources. The URN is remembered for
the rest of the program, so calling this again is cheap and does not register a
duplicate.
"""
function register_root_stack()::String
    isempty(_ROOT_STACK_URN[]) || return _ROOT_STACK_URN[]

    ctx = get_context()
    response = register_resource_rpc(ctx._monitor, Dict{String, Any}(
        "type" => "pulumi:pulumi:Stack",
        "name" => "$(ctx.project)-$(ctx.stack)",
        "parent" => "",
        "custom" => false,
        "object" => Dict{String, Any}(),
        "acceptSecrets" => true,
        "acceptResources" => true,
    ))

    _ROOT_STACK_URN[] = get(response, "urn", "")
    return _ROOT_STACK_URN[]
end

"""
    root_stack_urn() -> String

The URN of the root stack resource, or an empty string if it has not been
registered yet.
"""
root_stack_urn()::String = _ROOT_STACK_URN[]

"""
    clear_root_stack!()

Forget the registered root stack resource. Used when resetting the context
between programs.
"""
function clear_root_stack!()
    _ROOT_STACK_URN[] = ""
    return nothing
end

"""
    register_stack_outputs()

Publish the exported values as the stack's outputs.

They are attached to the root `pulumi:pulumi:Stack` resource, which is
registered on demand by [`register_root_stack`](@ref). Nothing is sent when the
program exported nothing.

[`run_program`](@ref) calls this once the program has finished; a program only
needs to call it directly when it drives the lifecycle itself.
"""
function register_stack_outputs()
    outputs = get_exports()
    if isempty(outputs)
        return
    end

    # Serialize outputs
    serialized = Dict{String, Any}()
    for (name, value) in outputs
        serialized[name] = serialize_property(value)
    end

    urn = register_root_stack()
    if isempty(urn)
        throw(PulumiError("Cannot publish stack outputs: the root stack resource has no URN"))
    end

    register_resource_outputs_rpc(get_context()._monitor, Dict{String, Any}(
        "urn" => urn,
        "outputs" => serialized,
    ))
    return nothing
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

"""
    run_program(path::AbstractString)

Execute a Pulumi program and publish the values it exported.

The Pulumi CLI never registers stack outputs on a program's behalf, so this is
what turns [`export_value`](@ref) and [`export_secret`](@ref) calls into the
stack outputs `pulumi stack output` reports. Every language host must run a
program through this function rather than `include` it directly.

The program is evaluated in `Main`, so the names it defines do not leak into
`Pulumi`, and the program's directory becomes the working directory while it
runs.

Outputs are published only when the program completes: a program that throws
leaves the stack's previous outputs untouched.
"""
function run_program(path::AbstractString)
    program = abspath(path)
    if !isfile(program)
        throw(ArgumentError("Pulumi program not found: $program"))
    end

    # The root stack resource must exist before the program registers anything,
    # because the engine parents the program's resources to it.
    register_root_stack()

    cd(dirname(program)) do
        Base.include(Main, program)
    end

    register_stack_outputs()
    return nothing
end
