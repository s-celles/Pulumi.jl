# Quick Start

This guide walks you through creating your first Pulumi program with Julia.

## Install the language host

The Pulumi CLI runs a Julia program through a language plugin, which you build
and install once from a checkout of this repository:

```bash
just plugin-install
```

`pulumi plugin ls` should then list `julia` as a `language` plugin. See the
[Language Host](@ref) guide for details.

## Create a New Project

There is no `pulumi new julia` template yet, so create the three files by hand:

```
my-pulumi-project/
├── Pulumi.yaml      # Project metadata, with `runtime: julia`
├── Project.toml     # Julia dependencies, including Pulumi
└── main.jl          # Your infrastructure code
```

`Pulumi.yaml`:

```yaml
name: my-pulumi-project
runtime: julia
description: My first Pulumi program in Julia
```

`Project.toml`:

```toml
name = "MyPulumiProject"
uuid = "00000000-0000-0000-0000-000000000000"  # any fresh UUID

[deps]
Pulumi = "90af1f71-c6d8-4a0a-9f87-1292e80e7fff"
```

Until Pulumi.jl is registered in the General registry, point the project at a
checkout of it:

```toml
[sources]
Pulumi = {path = "/path/to/Pulumi.jl"}
```

Then resolve the environment:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

!!! tip
    `examples/local` in the repository is a complete project along these lines
    that deploys without a cloud account, and `examples/simple` shows a
    realistic AWS program.

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
pulumi stack init dev

# Preview changes
pulumi preview

# Deploy
pulumi up
```

The example above registers an `aws:s3:Bucket`, so it needs the AWS provider
plugin and credentials. To try the workflow without a cloud account, use
component resources only, as `examples/local` does: the engine creates them
itself.

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
