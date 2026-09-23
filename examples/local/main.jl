#!/usr/bin/env julia
#
# A Pulumi Julia program that needs no cloud provider and no credentials.
#
# Component resources are handled by the Pulumi engine itself, so this runs
# against a local file backend and is the quickest way to check that the Julia
# language host is installed correctly.
#
# See examples/local/README.md for how to run it.

using Pulumi

config = Config()
environment = get(config, "environment", "dev")

log_info("Deploying the $(environment) environment")

# A component groups related resources. The engine creates it without asking a
# provider, which is why this example needs no credentials.
group = component("examples:local:Group", "demo-$(environment)") do parent
    inner = component("examples:local:Inner", "inner"; parent = parent) do _
        return nothing
    end
    return (inner = inner,)
end

register_outputs(group, Dict{String, Any}(
    "environment" => environment,
    "childCount" => length(group.children),
))

# Stack outputs. `pulumi stack output` reports these once the update finishes.
export_value("environment", environment)
export_value("groupUrn", get_urn(group))
export_value("project", get_project())

# A secret is stored encrypted and masked in the CLI's output.
export_secret("apiToken", "token-for-$(environment)")

log_info("Done")
