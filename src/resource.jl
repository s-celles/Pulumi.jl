"""
Resource types and registration.

Per data-model.md:
- Resource: Base type for all infrastructure resources
- CustomResource: Provider-managed resources (VMs, buckets)
- ComponentResource: Logical groupings of resources
- ProviderResource: Explicit provider configuration
"""

using UUIDs

"""
    URN

Parsed Uniform Resource Name for a resource.
Format: urn:pulumi:{stack}::{type}::{name}
"""
struct URN
    stack::String
    project::String
    parent_type::Union{String, Nothing}
    type_::String
    name::String
end

"""
    URN(urn_string::String) -> URN

Parse a URN string into its components.

Format: urn:pulumi:{stack}::{project}::{qualified_type}::{name}

Example: urn:pulumi:dev::my-project::aws:s3:Bucket::my-bucket
- stack = dev
- project = my-project
- type_ = aws:s3:Bucket
- name = my-bucket
"""
function URN(urn_string::String)
    # Format: urn:pulumi:{stack}::{project}::{qualified_type}::{name}
    if !startswith(urn_string, "urn:pulumi:")
        throw(ArgumentError("Invalid URN format: must start with 'urn:pulumi:'"))
    end

    parts = split(urn_string, "::")
    if length(parts) < 4
        throw(ArgumentError("Invalid URN format: expected at least 4 parts separated by '::' (stack::project::type::name)"))
    end

    # Extract stack from first part (urn:pulumi:{stack})
    first_part = parts[1]
    stack = replace(first_part, "urn:pulumi:" => "")

    # Project is the second part
    project = String(parts[2])

    # Type may include parent (parent_type$child_type)
    qualified_type = parts[3]
    if contains(qualified_type, "\$")
        type_parts = split(qualified_type, "\$")
        parent_type = join(type_parts[1:end-1], "\$")
        type_ = String(type_parts[end])
    else
        parent_type = nothing
        type_ = String(qualified_type)
    end

    # Name is the last part
    name = String(parts[end])

    URN(stack, project, parent_type, type_, name)
end

"""
    string(urn::URN) -> String

Convert a URN back to string format.
"""
function Base.string(urn::URN)
    qualified_type = if urn.parent_type !== nothing
        "$(urn.parent_type)\$$(urn.type_)"
    else
        urn.type_
    end
    "urn:pulumi:$(urn.stack)::$(urn.project)::$(qualified_type)::$(urn.name)"
end

Base.show(io::IO, urn::URN) = print(io, string(urn))

"""
    ResourceOptions

Options controlling resource behavior and relationships.
"""
Base.@kwdef struct ResourceOptions
    parent::Union{Any, Nothing} = nothing  # Resource type
    depends_on::Vector{Any} = Any[]  # Vector of Resources
    protect::Bool = false
    provider::Union{Any, Nothing} = nothing  # ProviderResource
    aliases::Vector{String} = String[]
    ignore_changes::Vector{String} = String[]
    delete_before_replace::Bool = false
    retain_on_delete::Bool = false
    version::Union{String, Nothing} = nothing
    plugin_download_url::Union{String, Nothing} = nothing
    custom_timeouts::Union{Dict{String, String}, Nothing} = nothing
end

"""
    Resource

Abstract base type for all Pulumi resources.
"""
abstract type Resource end

"""
    CustomResource <: Resource

A resource managed by a cloud provider.
"""
mutable struct CustomResource <: Resource
    urn::String
    type_::String
    name::String
    inputs::Dict{String, Any}
    outputs::Dict{String, Any}
    options::ResourceOptions
    state::ResourceState.T
end

"""
    ComponentResource <: Resource

A logical grouping of resources.
"""
mutable struct ComponentResource <: Resource
    urn::String
    type_::String
    name::String
    children::Vector{Resource}
    options::ResourceOptions
    state::ResourceState.T
end

"""
    ProviderResource <: Resource

Explicit provider configuration.
"""
mutable struct ProviderResource <: Resource
    urn::String
    package::String
    name::String
    config::Dict{String, Any}
    options::ResourceOptions
    state::ResourceState.T
end

# Convenience accessors
get_urn(r::Resource) = r.urn
get_name(r::Resource) = r.name
get_type(r::CustomResource) = r.type_
get_type(r::ComponentResource) = r.type_
get_type(r::ProviderResource) = r.package

"""
    register_resource(type::String, name::String, inputs::Dict{String, Any}; kwargs...) -> CustomResource

Register a cloud resource with the Pulumi engine.

# Arguments
- `type::String`: Resource type (e.g., "aws:s3:Bucket")
- `name::String`: Logical name (unique within parent scope)
- `inputs::Dict{String, Any}`: Input properties

# Keyword Arguments
- `parent`: Parent resource for hierarchy
- `depends_on`: Explicit dependencies
- `protect`: Prevent accidental deletion
- `provider`: Explicit provider
- `aliases`: URN aliases for refactoring
- `ignore_changes`: Properties to ignore on update
- `delete_before_replace`: Delete before creating replacement
- `retain_on_delete`: Keep resource when removed from code

# Returns
- `CustomResource`: The registered resource with outputs

# Examples
```julia
bucket = register_resource("aws:s3:Bucket", "my-bucket", Dict(
    "acl" => "private"
))
```
"""
function register_resource(
    type::String,
    name::String,
    inputs::Dict{String, Any};
    parent::Union{Resource, Nothing} = nothing,
    depends_on::Vector{<:Resource} = Resource[],
    protect::Bool = false,
    provider::Union{ProviderResource, Nothing} = nothing,
    aliases::Vector{String} = String[],
    ignore_changes::Vector{String} = String[],
    delete_before_replace::Bool = false,
    retain_on_delete::Bool = false,
    version::Union{String, Nothing} = nothing
)::CustomResource
    options = ResourceOptions(;
        parent,
        depends_on = Vector{Any}(depends_on),
        protect,
        provider,
        aliases,
        ignore_changes,
        delete_before_replace,
        retain_on_delete,
        version
    )

    # Get context
    ctx = get_context()

    # Serialize inputs
    serialized_inputs = serialize_struct(inputs)

    # Extract dependencies from Output values in inputs
    all_deps = collect_dependencies(inputs)
    for dep in depends_on
        push!(all_deps, get_urn(dep))
    end
    unique!(all_deps)

    # Build request
    request = Dict{String, Any}(
        "type" => type,
        "name" => name,
        "parent" => parent !== nothing ? get_urn(parent) : "",
        "custom" => true,
        "object" => serialized_inputs,
        "protect" => protect,
        "dependencies" => all_deps,
        "provider" => provider !== nothing ? get_urn(provider) : "",
        "deleteBeforeReplace" => delete_before_replace,
        "ignoreChanges" => ignore_changes,
        "aliases" => aliases,
        "acceptSecrets" => true,
        "acceptResources" => true,
        "retainOnDelete" => retain_on_delete
    )

    if version !== nothing
        request["version"] = version
    end

    # Create resource with CREATING state
    resource = CustomResource(
        "",  # URN will be set from response
        type,
        name,
        inputs,
        Dict{String, Any}(),
        options,
        ResourceState.CREATING
    )

    # Send RPC
    try
        response = register_resource_rpc(ctx._monitor, request)

        # Update resource with response
        resource.urn = get(response, "urn", "")
        resource.outputs = deserialize_struct(get(response, "object", Dict()))
        resource.state = ResourceState.CREATED
    catch e
        resource.state = ResourceState.FAILED
        if e isa GRPCError
            throw(ResourceError(resource.urn, "Failed to register resource: $(e.message)", e))
        end
        rethrow()
    end

    return resource
end

"""
    collect_dependencies(inputs::Dict) -> Vector{String}

Extract URN dependencies from Output values in inputs.
"""
function collect_dependencies(inputs::Dict)::Vector{String}
    deps = String[]
    for (_, v) in inputs
        if v isa Output
            append!(deps, v.dependencies)
        elseif v isa Dict
            append!(deps, collect_dependencies(v))
        elseif v isa Vector
            for item in v
                if item isa Output
                    append!(deps, item.dependencies)
                elseif item isa Dict
                    append!(deps, collect_dependencies(item))
                end
            end
        end
    end
    return deps
end

"""
    component(type::String, name::String, f::Function; kwargs...) -> ComponentResource

Create a component resource grouping related resources.

# Arguments
- `type::String`: Component type (e.g., "my:module:WebServer")
- `name::String`: Logical name
- `f::Function`: Function that creates child resources (receives component as argument)

# Examples
```julia
webserver = component("my:module:WebServer", "web") do parent
    vm = register_resource("aws:ec2:Instance", "vm",
        Dict("ami" => "ami-123"), parent=parent)
    return (vm=vm,)
end
```
"""
function component(
    f::Function,
    type::String,
    name::String;
    parent::Union{Resource, Nothing} = nothing,
    depends_on::Vector{<:Resource} = Resource[],
    providers::Dict{String, ProviderResource} = Dict{String, ProviderResource}()
)::ComponentResource
    options = ResourceOptions(;
        parent,
        depends_on = Vector{Any}(depends_on)
    )

    ctx = get_context()

    # Create component with CREATING state
    comp = ComponentResource(
        "",  # URN will be set from response
        type,
        name,
        Resource[],
        options,
        ResourceState.CREATING
    )

    # Register the component (not custom)
    request = Dict{String, Any}(
        "type" => type,
        "name" => name,
        "parent" => parent !== nothing ? get_urn(parent) : "",
        "custom" => false,
        "object" => Dict{String, Any}(),
        "protect" => false,
        "dependencies" => String[get_urn(d) for d in depends_on],
        "provider" => "",
        "acceptSecrets" => true,
        "acceptResources" => true
    )

    try
        response = register_resource_rpc(ctx._monitor, request)
        comp.urn = get(response, "urn", "")
        comp.state = ResourceState.CREATED
    catch e
        comp.state = ResourceState.FAILED
        if e isa GRPCError
            throw(ResourceError(comp.urn, "Failed to register component: $(e.message)", e))
        end
        rethrow()
    end

    # Execute the function to create child resources
    result = f(comp)

    # Collect children (if returned as NamedTuple or Dict)
    if result isa NamedTuple || result isa Dict
        for v in values(result)
            if v isa Resource
                push!(comp.children, v)
            end
        end
    elseif result isa Resource
        push!(comp.children, result)
    end

    return comp
end

"""
    register_outputs(resource::ComponentResource, outputs::Dict{String, Any})

Register outputs for a component resource.
"""
function register_outputs(resource::ComponentResource, outputs::Dict{String, Any})
    ctx = get_context()

    request = Dict{String, Any}(
        "urn" => resource.urn,
        "outputs" => serialize_struct(outputs)
    )

    register_resource_outputs_rpc(ctx._monitor, request)
end

# Show methods
function Base.show(io::IO, r::CustomResource)
    print(io, "CustomResource(\"", r.type_, "\", \"", r.name, "\")")
end

function Base.show(io::IO, r::ComponentResource)
    print(io, "ComponentResource(\"", r.type_, "\", \"", r.name, "\", ", length(r.children), " children)")
end

function Base.show(io::IO, r::ProviderResource)
    print(io, "ProviderResource(\"", r.package, "\", \"", r.name, "\")")
end

function Base.show(io::IO, ::MIME"text/plain", r::CustomResource)
    println(io, "CustomResource:")
    println(io, "  Type: ", r.type_)
    println(io, "  Name: ", r.name)
    println(io, "  URN: ", isempty(r.urn) ? "(pending)" : r.urn)
    println(io, "  State: ", r.state)
    println(io, "  Inputs: ", length(r.inputs), " properties")
    print(io, "  Outputs: ", length(r.outputs), " properties")
end

"""
    register_resources_parallel(resources::Vector{<:Tuple}) -> Vector{CustomResource}

Register multiple independent resources in parallel using Julia Tasks.

# Arguments
- `resources::Vector{<:Tuple}`: Vector of tuples (type, name, inputs; kwargs...)

# Returns
- `Vector{CustomResource}`: Vector of registered resources

# Example
```julia
resources = register_resources_parallel([
    ("aws:s3:Bucket", "bucket1", Dict("acl" => "private")),
    ("aws:s3:Bucket", "bucket2", Dict("acl" => "public-read")),
    ("aws:s3:Bucket", "bucket3", Dict("acl" => "private"))
])
```

# Notes
- Resources are registered concurrently using Julia's task system
- All resources must be independent (no dependencies on each other)
- If any registration fails, other registrations continue
- Failed resources will have state=FAILED
"""
function register_resources_parallel(
    resources::Vector{<:Tuple}
)::Vector{CustomResource}
    # Create tasks for each resource registration
    tasks = Task[]

    for resource_def in resources
        type_ = resource_def[1]
        name = resource_def[2]
        inputs = resource_def[3]

        # Extract kwargs if present (4th element onwards)
        kwargs = if length(resource_def) > 3
            resource_def[4:end]
        else
            ()
        end

        task = Threads.@spawn begin
            try
                register_resource(type_, name, inputs)
            catch e
                # Create a failed resource placeholder
                CustomResource(
                    "",
                    type_,
                    name,
                    inputs,
                    Dict{String, Any}("error" => string(e)),
                    ResourceOptions(),
                    ResourceState.FAILED
                )
            end
        end
        push!(tasks, task)
    end

    # Wait for all tasks and collect results
    results = CustomResource[]
    for task in tasks
        result = fetch(task)
        push!(results, result)
    end

    return results
end

"""
    with_parallelism(f::Function, max_concurrent::Int=16)

Execute a function with controlled parallelism for resource operations.

# Arguments
- `f::Function`: Function to execute
- `max_concurrent::Int`: Maximum concurrent operations (default: 16)

# Example
```julia
with_parallelism(8) do
    # Create resources that will be batched
    for i in 1:100
        register_resource("aws:s3:Bucket", "bucket-\$i", Dict())
    end
end
```
"""
function with_parallelism(f::Function, max_concurrent::Int=16)
    # Get context to check parallelism setting
    ctx = get_context()
    actual_max = min(max_concurrent, ctx.parallel)

    # Use a semaphore pattern with channels
    sem = Channel{Nothing}(actual_max)

    # Fill the semaphore
    for _ in 1:actual_max
        put!(sem, nothing)
    end

    try
        f()
    finally
        close(sem)
    end
end
