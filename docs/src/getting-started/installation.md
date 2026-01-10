# Installation

## Prerequisites

Before using Pulumi.jl, ensure you have:

1. **Julia 1.9+**: Download from [julialang.org](https://julialang.org/downloads/)
2. **Pulumi CLI**: Install from [pulumi.com/docs/install](https://www.pulumi.com/docs/install/)

## Installing Pulumi.jl

### From the Julia Package Registry

```julia
using Pkg
Pkg.add("Pulumi")
```

### From Source (Development)

```julia
using Pkg
Pkg.develop(url="https://github.com/pulumi/pulumi-julia.git")
```

## Verifying Installation

```julia
using Pulumi

# Check that the module loads correctly
@info "Pulumi.jl version loaded successfully"
```

## Cloud Provider Setup

Pulumi.jl works with any Pulumi provider. Configure your cloud credentials:

### AWS

```bash
export AWS_ACCESS_KEY_ID=<your-access-key>
export AWS_SECRET_ACCESS_KEY=<your-secret-key>
export AWS_REGION=us-east-1
```

Or use AWS CLI: `aws configure`

### Azure

```bash
az login
```

### Google Cloud

```bash
gcloud auth application-default login
```

## Next Steps

- Follow the [Quick Start](quickstart.md) guide to create your first infrastructure
- Learn about [Resources](../guides/resources.md) and how to create them
