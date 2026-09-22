# Internals

This page documents the non-exported parts of Pulumi.jl: the gRPC handlers the
Pulumi CLI calls, the protobuf serialization layer and the dependency-graph
helpers.

!!! warning
    Nothing on this page is public API. These names are not exported, are not
    covered by the package's semantic versioning promise, and may change in any
    release.

## Module

```@docs
Pulumi.Pulumi
```

## LanguageRuntime Handlers

Each handler implements one RPC of the `pulumirpc.LanguageRuntime` service.

```@docs
Pulumi.handle_handshake
Pulumi.handle_run
Pulumi.handle_get_plugin_info
Pulumi.handle_about
Pulumi.handle_get_required_plugins
Pulumi.handle_install_dependencies
Pulumi.handle_get_program_dependencies
Pulumi.handle_runtime_options
Pulumi.resolve_program_directory
Pulumi.project_dependencies
Pulumi.manifest_versions
Pulumi.pump_pipe
gRPCServer.service_descriptor
```

## Serialization

```@docs
Pulumi.serialize_struct
Pulumi.serialize_property
Pulumi.serialize_list
Pulumi.serialize_output
Pulumi.deserialize_struct
Pulumi.deserialize_property
Pulumi.deserialize_list
Pulumi.dict_to_struct
Pulumi.struct_to_dict
Pulumi.julia_to_value
Pulumi.value_to_julia
Pulumi.is_secret_value
Pulumi.unwrap_secret
```

## gRPC Plumbing

```@docs
Pulumi._parse_address
Pulumi._build_register_resource_request
Pulumi._build_aliases
Pulumi._build_custom_timeouts
Pulumi.with_retry
Pulumi.is_retryable_code
Pulumi.with_log_stream
```

## Dependency Graph Internals

```@docs
Pulumi.collect_dependencies
Pulumi.would_create_cycle
Pulumi.find_cycle_path
Pulumi.can_reach
```

## Context Internals

```@docs
Pulumi.Context
```

## Base Extensions

```@docs
Base.string(::Pulumi.URN)
Base.getindex(::Pulumi.Config, ::String)
```

## Macros

```@docs
Pulumi.@export_output
```
