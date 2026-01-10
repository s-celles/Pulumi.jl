# Configuration

Pulumi configuration allows you to parameterize your infrastructure with stack-specific values.

## Setting Configuration

Use the Pulumi CLI to set configuration values:

```bash
# Set a plain value
pulumi config set bucketName my-bucket

# Set a secret value
pulumi config set --secret databasePassword s3cr3t
```

## Reading Configuration

### Basic Usage

```julia
using Pulumi

config = Config()

# Get a value (returns nothing if not set)
bucket_name = get(config, "bucketName")

# Get with default
bucket_name = get(config, "bucketName", "default-bucket")

# Require a value (throws if not set)
bucket_name = require(config, "bucketName")
```

### Bracket Syntax

```julia
config = Config()
bucket_name = config["bucketName"]  # Throws ConfigMissingError if not set
```

## Typed Accessors

Convert configuration values to specific types:

```julia
config = Config()

# Integer
port = get_int(config, "port")

# Boolean
enabled = get_bool(config, "featureEnabled")

# Float
threshold = get_float(config, "threshold")

# JSON Object
settings = get_object(config, "complexSettings")
```

## Secrets

Access secret configuration values:

```julia
config = Config()

# Check if a key is a secret
if is_secret(config, "password")
    @info "Password is stored as a secret"
end

# Get secret as Output (returns nothing if not set)
password = get_secret(config, "password")

# Require secret (throws if not set)
password = require_secret(config, "password")
```

Secret values are returned as `Output{String}` with `is_secret=true`.

## Namespaces

Configuration keys are namespaced by project. Use a custom namespace:

```julia
# Default namespace (current project)
config = Config()

# Custom namespace
aws_config = Config("aws")
region = get(aws_config, "region")
```

## Example

```julia
using Pulumi

config = Config()

# Read configuration
env = get(config, "environment", "dev")
instance_count = get_int(config, "instanceCount") ?? 1
db_password = require_secret(config, "dbPassword")

# Use in resources
for i in 1:instance_count
    register_resource("aws:ec2:Instance", "server-\$i", Dict{String,Any}(
        "tags" => Dict("Environment" => env)
    ))
end
```

## Error Handling

```julia
config = Config()

try
    value = require(config, "missingKey")
catch e
    if e isa ConfigMissingError
        @error "Configuration key not found" key=e.key
    end
end
```
