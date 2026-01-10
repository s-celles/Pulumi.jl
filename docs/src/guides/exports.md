# Stack Exports

Stack exports allow you to expose values from your infrastructure for use by other stacks
or external systems.

## Exporting Values

Use `export_value` to expose a value:

```julia
using Pulumi

bucket = register_resource("aws:s3:Bucket", "my-bucket", Dict{String,Any}())

# Export a simple value
export_value("bucket_arn", bucket.outputs["arn"])

# Export a computed value
export_value("bucket_url", apply(bucket.outputs["bucket"]) do name
    "https://\$(name).s3.amazonaws.com"
end)
```

## Exporting Secrets

Use `export_secret` for sensitive values:

```julia
db = register_resource("aws:rds:Instance", "database", Dict{String,Any}(
    "engine" => "postgres",
    "password" => "temporary-password"
))

# Export as secret (won't appear in plain text)
export_secret("db_connection_string", apply(db.outputs) do outputs
    "postgres://user:\$(outputs[\"password\"])@\$(outputs[\"endpoint\"])/mydb"
end)
```

## Viewing Exports

After deployment, view exports with the CLI:

```bash
# View all exports
pulumi stack output

# View a specific export
pulumi stack output bucket_arn

# View secrets (shows plain text)
pulumi stack output db_connection_string --show-secrets
```

## Cross-Stack References

Export values from one stack and import them in another:

### Exporting Stack (network stack)

```julia
# network/main.jl
using Pulumi

vpc = register_resource("aws:ec2:Vpc", "main", Dict{String,Any}(
    "cidrBlock" => "10.0.0.0/16"
))

export_value("vpc_id", vpc.outputs["id"])
export_value("vpc_cidr", vpc.outputs["cidrBlock"])
```

### Importing Stack (app stack)

```julia
# app/main.jl
using Pulumi

# Reference another stack's outputs
# (This would use invoke with the pulumi:pulumi:StackReference provider)
network_stack = invoke("pulumi:pulumi:StackReference", Dict{String,Any}(
    "name" => "organization/network/production"
))

# Use the exported value
app = register_resource("aws:ec2:Instance", "app", Dict{String,Any}(
    "subnetId" => network_stack.outputs["vpc_id"]
))
```

## Managing Exports

### Viewing Current Exports

```julia
exports = get_exports()
for (name, value) in exports
    @info "Export" name=name
end
```

### Clearing Exports (Testing)

```julia
clear_exports!()  # Clears all registered exports
```

## Best Practices

1. **Use descriptive names**: Export names should clearly indicate their purpose

2. **Export Outputs, not raw values**: Wrap values in Output for proper tracking

3. **Mark secrets appropriately**: Use `export_secret` for passwords, keys, and tokens

4. **Document exports**: Include comments explaining what each export represents

5. **Minimize exports**: Only export values that other stacks or systems need

## Example: Full Application

```julia
using Pulumi

config = Config()
env = get(config, "environment", "dev")

# Create infrastructure
db = register_resource("aws:rds:Instance", "database", Dict{String,Any}(
    "engine" => "postgres",
    "instanceClass" => "db.t3.micro"
))

bucket = register_resource("aws:s3:Bucket", "assets", Dict{String,Any}(
    "acl" => "private"
))

# Export connection information
export_value("database_endpoint", db.outputs["endpoint"])
export_value("database_port", db.outputs["port"])
export_secret("database_password", db.outputs["password"])

export_value("assets_bucket", bucket.outputs["bucket"])
export_value("assets_bucket_arn", bucket.outputs["arn"])

# Export metadata
export_value("environment", Output(env))
export_value("stack", Output(get_stack()))
```
