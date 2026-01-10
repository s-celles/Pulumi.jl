# Component Resources

Components allow you to create reusable abstractions that group related resources together.

## Creating Components

Use the `component` function to create a component resource:

```julia
using Pulumi

webserver = component("my:module:WebServer", "production-web") do parent
    # Create child resources with parent reference
    vm = register_resource("aws:ec2:Instance", "vm", Dict{String,Any}(
        "ami" => "ami-0123456789",
        "instanceType" => "t2.micro"
    ), parent=parent)

    sg = register_resource("aws:ec2:SecurityGroup", "sg", Dict{String,Any}(
        "description" => "Web server security group",
        "ingress" => [
            Dict("protocol" => "tcp", "fromPort" => 80, "toPort" => 80)
        ]
    ), parent=parent)

    # Return child resources
    (vm=vm, sg=sg)
end
```

## Component Structure

Components establish a parent-child hierarchy in the Pulumi state:

```
my:module:WebServer::production-web
├── aws:ec2:Instance::vm
└── aws:ec2:SecurityGroup::sg
```

## Accessing Children

```julia
# Access child resources from the component
webserver.children  # Vector of child resources

# Access by name from returned tuple
webserver_result = component("my:module:WebServer", "web") do parent
    vm = register_resource(...)
    (vm=vm,)
end
# Note: Use the returned tuple, not webserver.children for named access
```

## Registering Outputs

Register component outputs for cross-stack references:

```julia
webserver = component("my:module:WebServer", "web") do parent
    vm = register_resource("aws:ec2:Instance", "vm", Dict{String,Any}(
        "ami" => "ami-123"
    ), parent=parent)

    (vm=vm,)
end

# Register outputs for the component
register_outputs(webserver, Dict{String,Any}(
    "publicIp" => webserver.children[1].outputs["publicIp"],
    "instanceId" => webserver.children[1].outputs["id"]
))
```

## Nested Components

Components can contain other components:

```julia
app = component("my:app:FullStack", "myapp") do parent
    # Frontend component
    frontend = component("my:app:Frontend", "frontend", parent=parent) do p
        bucket = register_resource("aws:s3:Bucket", "static", Dict{String,Any}(), parent=p)
        (bucket=bucket,)
    end

    # Backend component
    backend = component("my:app:Backend", "backend", parent=parent) do p
        db = register_resource("aws:rds:Instance", "db", Dict{String,Any}(
            "engine" => "postgres"
        ), parent=p)
        (db=db,)
    end

    (frontend=frontend, backend=backend)
end
```

## Best Practices

1. **Use meaningful type names**: Follow the pattern `organization:module:ResourceType`

2. **Always pass parent**: Child resources should reference the component as their parent

3. **Return a named tuple**: Return child resources for easy access

4. **Register outputs**: Make important values accessible via `register_outputs`

5. **Document inputs**: Clearly document what configuration your component expects

## Example: VPC Component

```julia
function create_vpc(name::String; cidr::String = "10.0.0.0/16")
    component("my:network:VPC", name) do parent
        vpc = register_resource("aws:ec2:Vpc", "vpc", Dict{String,Any}(
            "cidrBlock" => cidr,
            "enableDnsHostnames" => true
        ), parent=parent)

        public_subnet = register_resource("aws:ec2:Subnet", "public", Dict{String,Any}(
            "vpcId" => vpc.outputs["id"],
            "cidrBlock" => "10.0.1.0/24",
            "mapPublicIpOnLaunch" => true
        ), parent=parent, depends_on=[vpc])

        private_subnet = register_resource("aws:ec2:Subnet", "private", Dict{String,Any}(
            "vpcId" => vpc.outputs["id"],
            "cidrBlock" => "10.0.2.0/24"
        ), parent=parent, depends_on=[vpc])

        (vpc=vpc, public_subnet=public_subnet, private_subnet=private_subnet)
    end
end

# Usage
network = create_vpc("production", cidr="10.0.0.0/16")
```
