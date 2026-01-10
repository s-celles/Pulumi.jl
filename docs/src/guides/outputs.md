# Outputs

`Output{T}` is a core type representing values that may not be known until deployment time.
Resource properties, computed values, and secrets are all represented as Outputs.

## Understanding Outputs

When you create a resource, its properties aren't immediately available. For example,
an AWS EC2 instance's public IP address is only known after the instance is created.
Pulumi represents these values as `Output{T}`.

```julia
using Pulumi

bucket = register_resource("aws:s3:Bucket", "my-bucket", Dict{String,Any}())

# bucket.outputs["arn"] is an Output{String}
# The actual value isn't known until deployment
```

## Creating Outputs

### Known Values

```julia
output = Output("hello")       # Output{String} with known value
output = Output(42)            # Output{Int} with known value
```

### Unknown Values (Preview Mode)

```julia
output = Output{String}()      # Unknown Output{String}
```

### Secret Values

```julia
secret = Output("password", is_secret=true)
```

## Transforming Outputs with `apply`

Use `apply` to transform Output values:

```julia
bucket_name = Output("my-bucket")

# Transform the value
upper_name = apply(bucket_name) do name
    uppercase(name)
end
# => Output{String} containing "MY-BUCKET"
```

### Chaining Transformations

```julia
url = apply(bucket.outputs["bucket"]) do bucket_name
    apply(bucket.outputs["region"]) do region
        "https://\$(bucket_name).s3.\$(region).amazonaws.com"
    end
end
```

## Combining Outputs with `all`

Combine multiple Outputs into one:

```julia
name = Output("my-app")
env = Output("production")

combined = all(name, env)
# => Output{Tuple{String, String}}

message = apply(combined) do (n, e)
    "\$(n) running in \$(e)"
end
```

## Secret Handling

Outputs can be marked as secrets to prevent them from appearing in logs:

```julia
password = Output("s3cr3t", is_secret=true)

# Secrets propagate through transformations
derived = apply(password) do p
    "prefix-\$(p)"
end
# derived.is_secret == true
```

## Checking Output State

```julia
output = Output("value")

output.is_known      # true if value is available
output.is_secret     # true if value is a secret
output.value         # the underlying value (if known)
output.dependencies  # URNs this output depends on
```

## Type Stability

Pulumi.jl maintains type stability through Output transformations:

```julia
int_output = Output(42)
str_output = apply(int_output) do x
    string(x)
end
# str_output is Output{String}
```
