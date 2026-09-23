# AWS example

Shows the shape of a realistic Pulumi Julia program: configuration, resources,
`apply` over outputs, a component grouping children, and stack outputs.

> **This example cannot be deployed as-is.** It registers `aws:*` resources, so
> it needs the AWS provider plugin and valid AWS credentials, and it would
> create billable infrastructure. Read it as a reference.
>
> For something you can actually run, see [`../local`](../local), which needs no
> cloud account.

## What it demonstrates

| Feature | Where |
|---|---|
| Typed configuration with defaults | `Config()`, `get(config, "environment", "dev")` |
| Logging through the engine | `log_info` |
| Resource registration | `register_resource("aws:s3:Bucket", ...)` |
| Transforming an output | `apply(bucket.outputs["bucket"]) do name ... end` |
| Component resources with children | `component("my:module:WebServer", ...)` |
| Combining several outputs | `Pulumi.all(...)` |
| Stack outputs, including secrets | `export_value`, `export_secret` |

## If you do want to deploy it

```bash
cd examples/simple
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# AWS credentials must be configured, e.g. through `aws configure`.
pulumi stack init dev
pulumi config set environment dev
pulumi up
```

The language host must be installed first: run `just plugin-install` from the
repository root.
