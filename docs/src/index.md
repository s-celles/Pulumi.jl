# Pulumi.jl

> **Disclaimer**: This is a community-developed Julia SDK for Pulumi. It is **not** an official product of Pulumi Corporation. For official Pulumi language SDKs, see [pulumi.com/docs](https://www.pulumi.com/docs/).

Julia SDK for Pulumi Infrastructure as Code.

Pulumi.jl provides Julia developers with native syntax to define, deploy, and manage
cloud infrastructure using the Pulumi platform.

## Features

- **Native Julia Syntax**: Write infrastructure code using familiar Julia constructs
- **Type-Safe Outputs**: `Output{T}` parametric type for compile-time type checking
- **Dependency Management**: Automatic dependency tracking between resources
- **Component Resources**: Create reusable infrastructure abstractions
- **Configuration**: Stack-specific configuration with typed accessors
- **Parallel Execution**: Concurrent resource registration for improved performance

## Quick Example

```julia
using Pulumi

# Create a storage bucket
bucket = register_resource("aws:s3:Bucket", "my-bucket", Dict(
    "acl" => "private"
))

# Export the bucket name
export_value("bucket_name", apply(bucket.outputs["bucket"]) do b
    b
end)
```

## Installation

```julia
using Pkg
Pkg.add("Pulumi")
```

## Documentation

```@contents
Pages = [
    "getting-started/installation.md",
    "getting-started/quickstart.md",
    "guides/resources.md",
    "guides/outputs.md",
    "guides/configuration.md",
    "guides/components.md",
    "guides/exports.md",
    "api.md",
]
Depth = 2
```

## Getting Help

- [GitHub Issues](https://github.com/pulumi/pulumi-julia/issues)
- [Pulumi Community Slack](https://slack.pulumi.com/)
- [Pulumi Documentation](https://www.pulumi.com/docs/)
