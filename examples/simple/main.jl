#!/usr/bin/env julia
"""
Simple Pulumi Julia SDK Example

NOTE: This is a community-developed Julia SDK for Pulumi. It is NOT an official
product of Pulumi Corporation.

This example demonstrates basic usage of the Pulumi Julia SDK:
1. Reading configuration values
2. Creating resources
3. Using Outputs and apply()
4. Creating component resources
5. Exporting stack outputs

To run this example:
1. pulumi new julia --name my-project
2. Copy this file as main.jl
3. pulumi up
"""

using Pulumi

# Read configuration
config = Config()
env = get(config, "environment", "dev")
bucket_prefix = get(config, "bucketPrefix", "my-app")

# Log that we're starting
log_info("Starting infrastructure deployment for environment: $env")

# Create a simple S3 bucket resource
bucket = register_resource("aws:s3:Bucket", "my-bucket", Dict{String,Any}(
    "bucket" => "$(bucket_prefix)-$(env)-bucket",
    "acl" => "private",
    "tags" => Dict{String,Any}(
        "Environment" => env,
        "ManagedBy" => "Pulumi-Julia"
    )
))

log_info("Created bucket", resource=bucket)

# Use apply() to transform outputs
bucket_url = apply(bucket.outputs["bucket"]) do name
    "https://$(name).s3.amazonaws.com"
end

# Create a component resource to group related infrastructure
webserver = component("my:module:WebServer", "web-$(env)") do parent
    # Create an EC2 instance (child of the component)
    instance = register_resource("aws:ec2:Instance", "web-instance", Dict{String,Any}(
        "ami" => "ami-0123456789abcdef0",
        "instanceType" => "t2.micro",
        "tags" => Dict{String,Any}(
            "Name" => "WebServer-$(env)",
            "Environment" => env
        )
    ), parent=parent)

    # Create a security group (child of the component)
    sg = register_resource("aws:ec2:SecurityGroup", "web-sg", Dict{String,Any}(
        "description" => "Security group for web server",
        "ingress" => [
            Dict{String,Any}(
                "protocol" => "tcp",
                "fromPort" => 80,
                "toPort" => 80,
                "cidrBlocks" => ["0.0.0.0/0"]
            ),
            Dict{String,Any}(
                "protocol" => "tcp",
                "fromPort" => 443,
                "toPort" => 443,
                "cidrBlocks" => ["0.0.0.0/0"]
            )
        ]
    ), parent=parent)

    # Return the child resources
    (instance=instance, sg=sg)
end

# Register component outputs
register_outputs(webserver, Dict{String,Any}(
    "instanceId" => webserver.children[1].outputs["id"],
))

# Combine multiple outputs
combined = Pulumi.all(
    Output(env),
    bucket.outputs["arn"]
)

app_info = apply(combined) do (e, arn)
    "App running in $e with bucket: $arn"
end

# Export stack outputs
export_value("environment", Output(env))
export_value("bucket_name", bucket.outputs["bucket"])
export_value("bucket_url", bucket_url)
export_value("bucket_arn", bucket.outputs["arn"])
export_value("app_info", app_info)

# Export a secret (database password would normally come from config)
if get(config, "dbPassword") !== nothing
    export_secret("db_password", get_secret(config, "dbPassword"))
end

log_info("Infrastructure deployment complete!")
