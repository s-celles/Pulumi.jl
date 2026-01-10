# Quick Start

This guide walks you through creating your first Pulumi program with Julia.

## Create a New Project

```bash
mkdir my-pulumi-project
cd my-pulumi-project
pulumi new julia
```

This creates a basic project structure:

```
my-pulumi-project/
├── Pulumi.yaml      # Project metadata
├── Pulumi.dev.yaml  # Stack configuration
├── Project.toml     # Julia dependencies
└── main.jl          # Your infrastructure code
```

## Write Infrastructure Code

Edit `main.jl` to define your infrastructure:

```julia
using Pulumi

# Read configuration
config = Config()
bucket_name = get(config, "bucketName", "my-default-bucket")

# Create an S3 bucket
bucket = register_resource("aws:s3:Bucket", "my-bucket", Dict{String,Any}(
    "bucket" => bucket_name,
    "acl" => "private",
    "tags" => Dict(
        "Environment" => get_stack(),
        "ManagedBy" => "Pulumi"
    )
))

# Export the bucket name
export_value("bucket_name", apply(bucket.outputs["bucket"]) do b
    b
end)
```

## Deploy Your Infrastructure

```bash
# Preview changes
pulumi preview

# Deploy
pulumi up
```

## View Outputs

```bash
pulumi stack output bucket_name
```

## Clean Up

```bash
pulumi destroy
```

## Next Steps

- Learn about [Output chaining](../guides/outputs.md)
- Create [Component resources](../guides/components.md)
- Read [Configuration](../guides/configuration.md) values
