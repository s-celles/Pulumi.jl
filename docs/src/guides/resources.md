# Resources

Resources are the fundamental building blocks of Pulumi programs. Each resource represents
a piece of infrastructure, such as a virtual machine, storage bucket, or network.

## Creating Resources

Use `register_resource` to create a cloud resource:

```julia
using Pulumi

bucket = register_resource("aws:s3:Bucket", "my-bucket", Dict{String,Any}(
    "acl" => "private"
))
```

### Arguments

- `type::String`: The resource type (e.g., `"aws:s3:Bucket"`, `"azure:storage:Account"`)
- `name::String`: A unique logical name for the resource
- `inputs::Dict{String,Any}`: Input properties for the resource

### Resource Options

Control resource behavior with keyword arguments:

```julia
bucket = register_resource("aws:s3:Bucket", "my-bucket", Dict{String,Any}(),
    protect = true,                    # Prevent accidental deletion
    depends_on = [other_resource],     # Explicit dependencies
    ignore_changes = ["tags"],         # Ignore certain property changes
    delete_before_replace = true,      # Delete before creating replacement
    retain_on_delete = false           # Keep resource when removed from code
)
```

## Resource Types

### CustomResource

Provider-managed resources like VMs, buckets, and databases:

```julia
vm = register_resource("aws:ec2:Instance", "web-server", Dict{String,Any}(
    "ami" => "ami-0123456789",
    "instanceType" => "t2.micro"
))
```

### ComponentResource

Logical groupings of related resources:

```julia
webserver = component("my:module:WebServer", "web") do parent
    vm = register_resource("aws:ec2:Instance", "vm", Dict{String,Any}(
        "ami" => "ami-123"
    ), parent=parent)

    sg = register_resource("aws:ec2:SecurityGroup", "sg", Dict{String,Any}(
        "description" => "Web server security group"
    ), parent=parent)

    (vm=vm, sg=sg)
end
```

### ProviderResource

Explicit provider configuration for multi-region or multi-account deployments:

```julia
# Create an AWS provider for a specific region
provider = ProviderResource(
    "",
    "aws",
    "us-west-provider",
    Dict{String,Any}("region" => "us-west-2"),
    ResourceOptions(),
    ResourceState.CREATED
)
```

## Parallel Resource Creation

Register multiple independent resources concurrently:

```julia
resources = register_resources_parallel([
    ("aws:s3:Bucket", "bucket1", Dict{String,Any}("acl" => "private")),
    ("aws:s3:Bucket", "bucket2", Dict{String,Any}("acl" => "private")),
    ("aws:s3:Bucket", "bucket3", Dict{String,Any}("acl" => "private"))
])
```

## Resource URNs

Every resource has a Uniform Resource Name (URN) that uniquely identifies it:

```julia
urn = get_urn(bucket)
# => "urn:pulumi:dev::my-project::aws:s3:Bucket::my-bucket"
```

## Accessing Resource Properties

```julia
name = get_name(bucket)   # => "my-bucket"
type = get_type(bucket)   # => "aws:s3:Bucket"
```
