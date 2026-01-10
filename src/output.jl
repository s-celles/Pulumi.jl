"""
Output type for values that may be unknown until deployment.

Per constitution's Output-Centric Async Model principle:
- Output{T} for all values unknown until deployment
- apply(f, output) for value transformation
- all(outputs...) for combining multiple Outputs
- Secret tracking through Output metadata
"""

using UUIDs

"""
    Unknown

Sentinel type indicating a value is not yet known (preview mode).
"""
struct Unknown end

Base.show(io::IO, ::Unknown) = print(io, "<unknown>")

"""
    Output{T}

Container for values that may be unknown until deployment time.
Supports transformations and tracks dependencies for resource ordering.

# Fields
- `id::String`: Unique identifier (UUID)
- `value::Union{T, Unknown}`: Resolved value or Unknown sentinel
- `is_secret::Bool`: True if value should be encrypted in state
- `is_known::Bool`: True if value is resolved
- `dependencies::Vector{String}`: URNs of resources this Output depends on

# Examples
```julia
# Create a known output
output = Output{String}("hello")

# Create an unknown output (preview mode)
output = Output{String}()

# Create a secret output
output = Output{String}("secret-value", is_secret=true)
```
"""
struct Output{T}
    id::String
    value::Union{T, Unknown}
    is_secret::Bool
    is_known::Bool
    dependencies::Vector{String}

    # Inner constructor for validation
    function Output{T}(
        id::String,
        value::Union{T, Unknown},
        is_secret::Bool,
        is_known::Bool,
        dependencies::Vector{String}
    ) where T
        # Validate: is_known must be false if value is Unknown
        if value isa Unknown && is_known
            throw(ArgumentError("is_known cannot be true when value is Unknown"))
        end
        new{T}(id, value, is_secret, is_known, dependencies)
    end
end

# Convenience constructors

"""
    Output{T}(value::T; is_secret=false, dependencies=[])

Create a known Output with a resolved value.
"""
function Output{T}(
    value::T;
    is_secret::Bool = false,
    dependencies::Vector{String} = String[]
) where T
    Output{T}(string(uuid4()), value, is_secret, true, dependencies)
end

"""
    Output{T}(; is_secret=false, dependencies=[])

Create an unknown Output (for preview mode).
"""
function Output{T}(;
    is_secret::Bool = false,
    dependencies::Vector{String} = String[]
) where T
    Output{T}(string(uuid4()), Unknown(), is_secret, false, dependencies)
end

"""
    Output(value::T; kwargs...)

Create an Output with type inferred from value.
"""
function Output(value::T; kwargs...) where T
    Output{T}(value; kwargs...)
end

# Type-preserving secret marking
"""
    secret(output::Output{T}) -> Output{T}

Mark an Output as containing a secret value.
"""
function secret(output::Output{T})::Output{T} where T
    Output{T}(output.id, output.value, true, output.is_known, output.dependencies)
end

# Accessor functions
"""
    is_known(output::Output) -> Bool

Check if the Output value is known (resolved).
"""
is_known(output::Output) = output.is_known

"""
    is_secret(output::Output) -> Bool

Check if the Output contains a secret value.
"""
is_secret(output::Output) = output.is_secret

"""
    get_value(output::Output{T}) -> T

Get the resolved value from an Output.
Throws an error if the value is unknown.
"""
function get_value(output::Output{T})::T where T
    if !output.is_known
        throw(ArgumentError("Cannot get value from unknown Output"))
    end
    output.value::T
end

# Show method
function Base.show(io::IO, output::Output{T}) where T
    print(io, "Output{", T, "}(")
    if output.is_known
        if output.is_secret
            print(io, "[secret]")
        else
            show(io, output.value)
        end
    else
        print(io, "<unknown>")
    end
    print(io, ")")
end

function Base.show(io::IO, ::MIME"text/plain", output::Output{T}) where T
    print(io, "Output{", T, "}")
    if output.is_known
        print(io, " (known")
    else
        print(io, " (unknown")
    end
    if output.is_secret
        print(io, ", secret")
    end
    if !isempty(output.dependencies)
        print(io, ", ", length(output.dependencies), " deps")
    end
    print(io, "): ")
    if output.is_known && !output.is_secret
        show(io, output.value)
    elseif output.is_secret
        print(io, "[secret]")
    else
        print(io, "<unknown>")
    end
end

"""
    apply(f::Function, output::Output{T}) -> Output

Transform an Output value, preserving dependencies and secret status.
Type inference is performed at compile time using Core.Compiler.return_type.

# Arguments
- `f::Function`: Transformation function `T -> R`
- `output::Output{T}`: Input Output

# Returns
- `Output{R}`: Transformed Output with same dependencies and secret status

# Examples
```julia
output = Output{Int}(42)
doubled = apply(x -> x * 2, output)
# doubled isa Output{Int} with value 84
```
"""
function apply(f::F, output::Output{T})::Output where {F<:Function, T}
    # Infer return type at compile time
    R = Core.Compiler.return_type(f, Tuple{T})

    if output.is_known && !(output.value isa Unknown)
        # Apply the function to the known value
        new_value = f(output.value::T)
        Output{R}(string(uuid4()), new_value, output.is_secret, true, output.dependencies)
    else
        # Preserve unknown status
        Output{R}(string(uuid4()), Unknown(), output.is_secret, false, output.dependencies)
    end
end

# Variant with function first (more Julian)
"""
    apply(output::Output{T}) do value
        # transform value
    end

Block syntax for applying a transformation to an Output.
"""
apply(output::Output) = f -> apply(f, output)

"""
    all(outputs::Output...) -> Output{Tuple}

Combine multiple Outputs into a single Output containing a tuple.
The combined Output is unknown if any input is unknown.
The combined Output is secret if any input is secret.
Dependencies are merged from all inputs.

# Examples
```julia
a = Output{Int}(1)
b = Output{String}("hello")
combined = all(a, b)
# combined isa Output{Tuple{Int, String}}
```
"""
function all(outputs::Output...)
    # Collect types for the tuple
    T = Tuple{(eltype(typeof(o)) for o in outputs)...}

    # Merge dependencies
    all_deps = String[]
    for o in outputs
        append!(all_deps, o.dependencies)
    end
    unique!(all_deps)

    # Check if all are known and if any is secret
    all_known = Base.all(o -> o.is_known, outputs)
    any_secret = any(o -> o.is_secret, outputs)

    if all_known
        # Create tuple of values
        values = tuple((o.value for o in outputs)...)
        Output{T}(string(uuid4()), values, any_secret, true, all_deps)
    else
        Output{T}(string(uuid4()), Unknown(), any_secret, false, all_deps)
    end
end

# Allow extracting the element type
Base.eltype(::Type{Output{T}}) where T = T
