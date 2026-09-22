# API Reference

## Core Types

```@docs
Output
Unknown
Resource
CustomResource
ComponentResource
ProviderResource
ResourceOptions
URN
Config
```

## Resource Functions

```@docs
register_resource
component
register_outputs
register_resources_parallel
with_parallelism
```

## Output Functions

```@docs
apply
Pulumi.all
```

## Provider Functions

```@docs
Pulumi.invoke
call
```

## Configuration Functions

```@docs
get
require
is_secret
get_secret
require_secret
get_int
get_bool
get_float
get_object
```

## Export Functions

```@docs
export_value
export_secret
get_exports
clear_exports!
```

## Context Functions

```@docs
get_stack
get_project
get_organization
is_dry_run
get_context
set_context!
reset_context!
```

## Resource Accessors

```@docs
get_urn
get_name
get_type
```

## Logging Functions

```@docs
Pulumi.log
log_debug
log_info
log_warn
log_error
```

## Dependency Graph

```@docs
DependencyGraph
add_node!
add_edge!
topological_sort
get_dependencies
get_all_dependencies
get_dependents
get_dependency_graph
reset_dependency_graph!
register_dependency!
register_resource_dependencies!
```

## Error Types

```@docs
PulumiError
ResourceError
GRPCError
ConfigMissingError
DependencyError
```

## Output Accessors

```@docs
Pulumi.is_known
Pulumi.get_value
Pulumi.secret
```

## Language Runtime Server

The language host the Pulumi CLI launches to execute a Julia program.

```@docs
JuliaLanguageRuntime
LanguageRuntimeServer
create_language_runtime_server
run_language_host
start_and_print_port!
run_server
stop_server!
```

## gRPC Clients

Low-level clients for the engine's `ResourceMonitor` and `Engine` services.
Most programs use the resource and logging functions above instead.

```@docs
MonitorClient
EngineClient
GRPCChannel
connect!
disconnect!
is_connected
register_resource_rpc
register_resource_outputs_rpc
invoke_rpc
read_resource_rpc
supports_feature_rpc
log_rpc
get_root_resource_rpc
```

## gRPC Status Codes

```@docs
GRPCStatusCode
GRPCLogSeverity
exception_to_grpc_code
is_retryable_grpc_code
log_severity_to_grpc
```

## Stack Outputs

```@docs
Pulumi.register_stack_outputs
```

## Enums

```@docs
LogSeverity
ResourceState
```
