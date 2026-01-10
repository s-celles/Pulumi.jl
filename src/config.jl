"""
Configuration access for Pulumi programs.

Per data-model.md:
- Config: Type-safe access to stack configuration
- Values from PULUMI_CONFIG environment variable (JSON)
- Secret keys from PULUMI_CONFIG_SECRET_KEYS
"""

"""
    Config

Type-safe access to stack configuration values.

# Fields
- `namespace::String`: Configuration namespace (usually project name)
"""
struct Config
    namespace::String
end

"""
    Config() -> Config

Create a Config using the current project as namespace.
"""
function Config()
    ctx = get_context()
    Config(ctx.project)
end

"""
    get(config::Config, key::String) -> Union{String, Nothing}

Get a configuration value by key.

# Arguments
- `config::Config`: Configuration instance
- `key::String`: Configuration key (without namespace)

# Returns
- `String`: The configuration value
- `nothing`: If key is not set
"""
function Base.get(config::Config, key::String)::Union{String, Nothing}
    ctx = get_context()
    full_key = "$(config.namespace):$key"
    get(ctx.config, full_key, nothing)
end

"""
    get(config::Config, key::String, default::String) -> String

Get a configuration value with a default.

# Arguments
- `config::Config`: Configuration instance
- `key::String`: Configuration key (without namespace)
- `default::String`: Default value if key is not set

# Returns
- `String`: The configuration value or default
"""
function Base.get(config::Config, key::String, default::String)::String
    value = get(config, key)
    value === nothing ? default : value
end

"""
    require(config::Config, key::String) -> String

Get a required configuration value.

# Arguments
- `config::Config`: Configuration instance
- `key::String`: Configuration key (without namespace)

# Returns
- `String`: The configuration value

# Throws
- `ConfigMissingError`: If key is not set
"""
function require(config::Config, key::String)::String
    value = get(config, key)
    if value === nothing
        throw(ConfigMissingError(key, config.namespace))
    end
    value
end

"""
    is_secret(config::Config, key::String) -> Bool

Check if a configuration key is marked as secret.

# Arguments
- `config::Config`: Configuration instance
- `key::String`: Configuration key (without namespace)

# Returns
- `Bool`: True if the key is a secret
"""
function is_secret(config::Config, key::String)::Bool
    ctx = get_context()
    full_key = "$(config.namespace):$key"
    full_key in ctx.config_secret_keys
end

"""
    get_secret(config::Config, key::String) -> Union{Output{String}, Nothing}

Get a secret configuration value wrapped in an Output.

# Arguments
- `config::Config`: Configuration instance
- `key::String`: Configuration key (without namespace)

# Returns
- `Output{String}`: The secret value wrapped as a secret Output
- `nothing`: If key is not set
"""
function get_secret(config::Config, key::String)::Union{Output{String}, Nothing}
    value = get(config, key)
    if value === nothing
        return nothing
    end
    Output(value; is_secret=true)
end

"""
    require_secret(config::Config, key::String) -> Output{String}

Get a required secret configuration value.

# Arguments
- `config::Config`: Configuration instance
- `key::String`: Configuration key (without namespace)

# Returns
- `Output{String}`: The secret value wrapped as a secret Output

# Throws
- `ConfigMissingError`: If key is not set
"""
function require_secret(config::Config, key::String)::Output{String}
    value = require(config, key)
    Output(value; is_secret=true)
end

"""
    get_int(config::Config, key::String) -> Union{Int, Nothing}

Get a configuration value as an integer.

# Arguments
- `config::Config`: Configuration instance
- `key::String`: Configuration key (without namespace)

# Returns
- `Int`: The parsed integer value
- `nothing`: If key is not set

# Throws
- `ArgumentError`: If value cannot be parsed as integer
"""
function get_int(config::Config, key::String)::Union{Int, Nothing}
    value = get(config, key)
    value === nothing ? nothing : parse(Int, value)
end

"""
    get_bool(config::Config, key::String) -> Union{Bool, Nothing}

Get a configuration value as a boolean.

# Arguments
- `config::Config`: Configuration instance
- `key::String`: Configuration key (without namespace)

# Returns
- `Bool`: The parsed boolean value
- `nothing`: If key is not set
"""
function get_bool(config::Config, key::String)::Union{Bool, Nothing}
    value = get(config, key)
    if value === nothing
        return nothing
    end
    lowercase(value) in ("true", "1", "yes")
end

"""
    get_float(config::Config, key::String) -> Union{Float64, Nothing}

Get a configuration value as a float.

# Arguments
- `config::Config`: Configuration instance
- `key::String`: Configuration key (without namespace)

# Returns
- `Float64`: The parsed float value
- `nothing`: If key is not set

# Throws
- `ArgumentError`: If value cannot be parsed as float
"""
function get_float(config::Config, key::String)::Union{Float64, Nothing}
    value = get(config, key)
    value === nothing ? nothing : parse(Float64, value)
end

"""
    get_object(config::Config, key::String) -> Union{Dict{String, Any}, Nothing}

Get a configuration value as a JSON object.

# Arguments
- `config::Config`: Configuration instance
- `key::String`: Configuration key (without namespace)

# Returns
- `Dict{String, Any}`: The parsed JSON object
- `nothing`: If key is not set

# Throws
- On JSON parse error
"""
function get_object(config::Config, key::String)::Union{Dict{String, Any}, Nothing}
    value = get(config, key)
    value === nothing ? nothing : JSON3.read(value, Dict{String, Any})
end

"""
    getindex(config::Config, key::String) -> String

Access configuration value using bracket syntax.

# Arguments
- `config::Config`: Configuration instance
- `key::String`: Configuration key (without namespace)

# Returns
- `String`: The configuration value

# Throws
- `ConfigMissingError`: If key is not set

# Example
```julia
config = Config()
value = config["myKey"]  # Same as require(config, "myKey")
```
"""
function Base.getindex(config::Config, key::String)::String
    require(config, key)
end

# Show method
function Base.show(io::IO, config::Config)
    print(io, "Config(\"", config.namespace, "\")")
end
