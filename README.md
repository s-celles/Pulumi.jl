[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/s-celles/Pulumi.jl)

# Pulumi.jl

> **Disclaimer**: This is a community-developed Julia SDK for Pulumi. It is **not** an official product of Pulumi Corporation. For official Pulumi language SDKs, see [pulumi.com/docs](https://www.pulumi.com/docs/).

Julia SDK for [Pulumi](https://www.pulumi.com/) Infrastructure as Code.

Pulumi.jl provides Julia developers with native syntax to define, deploy, and manage
cloud infrastructure using the Pulumi platform.

## Installation

```julia
using Pkg
Pkg.add("Pulumi")
```

## Quick Start

```julia
using Pulumi

# Read configuration
config = Config()
env = get(config, "environment", "dev")

# Create a resource
bucket = register_resource("aws:s3:Bucket", "my-bucket", Dict{String,Any}(
    "acl" => "private",
    "tags" => Dict("Environment" => env)
))

# Transform outputs with apply()
bucket_url = apply(bucket.outputs["bucket"]) do name
    "https://$(name).s3.amazonaws.com"
end

# Export stack outputs
export_value("bucket_url", bucket_url)
```

## Features

- **Native Julia Syntax**: Write infrastructure code using familiar Julia constructs
- **Type-Safe Outputs**: `Output{T}` parametric type for compile-time type checking
- **Automatic Dependencies**: Dependency tracking between resources via Output references
- **Component Resources**: Create reusable infrastructure abstractions
- **Configuration**: Stack-specific configuration with typed accessors
- **Secret Handling**: Built-in secret support with proper encryption
- **Parallel Execution**: Concurrent resource registration for improved performance

## Core Types

| Type | Description |
|------|-------------|
| `Output{T}` | Container for values that may be unknown until deployment |
| `Resource` | Abstract base type for all infrastructure resources |
| `CustomResource` | Provider-managed resources (VMs, buckets, etc.) |
| `ComponentResource` | Logical groupings of related resources |
| `Config` | Stack configuration accessor |

## Core Functions

| Function | Description |
|----------|-------------|
| `register_resource` | Register a cloud resource |
| `component` | Create a component resource |
| `apply` | Transform Output values |
| `all` | Combine multiple Outputs |
| `invoke` | Call provider data source functions |
| `export_value` | Export stack outputs |
| `get_stack`, `get_project` | Access stack/project information |

## Examples

See the [examples](./examples) directory for complete examples:

- [simple](./examples/simple) - Basic resource creation and exports

## Documentation

Full documentation is available at the [Pulumi Julia SDK docs](./docs).

To build documentation locally:

```julia
using Pkg
Pkg.activate("docs")
include("docs/make.jl")
```

## Development

### Running Tests

```julia
using Pkg
Pkg.test("Pulumi")
```

### Updating Proto Files

When Pulumi releases new protocol versions, update the proto files and regenerate Julia bindings:

```bash
# Download latest protos and regenerate code
julia --project=. gen/download_protos.jl --generate

# Or step-by-step
julia --project=. gen/download_protos.jl      # Download protos
julia --project=. gen/generate_protos.jl      # Generate Julia code
```

See [docs/src/maintenance.md](./docs/src/maintenance.md) for the complete SDK maintenance guide.

### Project Structure

```
Pulumi.jl/
├── src/
│   ├── Pulumi.jl         # Main module
│   ├── output.jl         # Output{T} type
│   ├── resource.jl       # Resource types and registration
│   ├── config.jl         # Configuration access
│   ├── context.jl        # Execution context
│   ├── dependency.jl     # Dependency graph
│   ├── invoke.jl         # Provider function invocation
│   ├── export.jl         # Stack exports
│   ├── logging.jl        # Logging functions
│   ├── errors.jl         # Error types
│   ├── enums/            # Enum definitions
│   └── grpc/             # gRPC communication
├── test/                 # Test suite
├── docs/                 # Documentation
├── examples/             # Example programs
└── proto/                # Pulumi proto files
```

## Requirements

- Julia 1.10+
- Pulumi CLI

## License

This project is released under MIT license - See [LICENSE](./LICENSE) for details.

[Proto](https://protobuf.dev/programming-guides/proto3/) files from Pulumi Corporation are published under Apache License, Version 2.0.
