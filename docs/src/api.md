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
all
```

## Provider Functions

```@docs
invoke
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
log
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

## Enums

```@docs
LogSeverity
ResourceState
```
