"""
    Pulumi

Julia SDK for Pulumi Infrastructure as Code.

Provides Julia developers with native syntax to define, deploy, and manage
cloud infrastructure using the Pulumi platform.

# Exports

## Core Types
- `Output{T}`: Container for values that may be unknown until deployment
- `Resource`, `CustomResource`, `ComponentResource`, `ProviderResource`: Resource types
- `ResourceOptions`, `InvokeOptions`: Configuration options
- `Config`: Stack configuration accessor

## Core Functions
- `register_resource`: Register a cloud resource
- `component`: Create a component resource
- `apply`, `all`: Transform and combine Outputs
- `invoke`: Call provider data source functions
- `export_value`, `export_secret`: Export stack outputs
- `get_stack`, `get_project`: Access stack/project information

## Error Types
- `PulumiError`, `ResourceError`, `GRPCError`, `ConfigMissingError`

## Logging
- `log_debug`, `log_info`, `log_warn`, `log_error`
"""
module Pulumi

using UUIDs
using JSON3

# Include submodules in dependency order
include("enums/log_severity.jl")
include("enums/resource_state.jl")
include("errors.jl")
include("output.jl")
include("grpc/retry.jl")
include("grpc/serialize.jl")
include("grpc/client.jl")
include("context.jl")
include("resource.jl")
include("config.jl")
include("logging.jl")
include("invoke.jl")
include("export.jl")
include("dependency.jl")

# Core types
export Output, Unknown
export Resource, CustomResource, ComponentResource, ProviderResource
export ResourceOptions
export Config
export URN

# Core functions
export register_resource, component, register_outputs
export register_resources_parallel, with_parallelism
export apply, all
export invoke, call
export export_value, export_secret, get_exports, clear_exports!
export get_stack, get_project, get_organization, is_dry_run
export get_context, set_context!, reset_context!
export get_urn, get_name, get_type

# Config functions
export require, is_secret, get_secret, require_secret
export get_int, get_bool, get_float, get_object

# Error types
export PulumiError, ResourceError, GRPCError, ConfigMissingError, DependencyError

# Logging
export log, log_debug, log_info, log_warn, log_error

# Enums (module-scoped)
export LogSeverity, ResourceState

# Dependency graph
export DependencyGraph
export add_node!, add_edge!, topological_sort
export get_dependencies, get_all_dependencies, get_dependents
export get_dependency_graph, reset_dependency_graph!
export register_dependency!, register_resource_dependencies!

end # module Pulumi
