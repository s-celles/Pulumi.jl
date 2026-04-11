# Changelog

All notable changes to Pulumi.jl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Core SDK types: `Resource`, `CustomResource`, `ComponentResource`, `ProviderResource`, `ResourceOptions`, `URN`
- `Output{T}` parametric type with `apply`, `all`, `secret` support
- Resource registration: `register_resource`, `component`, `register_outputs`, parallel registration
- Dependency graph with cycle detection and topological sort
- `Config` type with typed accessors (`get_int`, `get_bool`, `get_float`, `get_object`)
- Context management: `get_stack`, `get_project`, `get_organization`, `is_dry_run`
- Stack exports: `export_value`, `export_secret`
- Provider function invocation: `invoke`, `call`
- Logging via Pulumi engine: `log_debug`, `log_info`, `log_warn`, `log_error`
- Error types: `PulumiError`, `ResourceError`, `GRPCError`, `ConfigMissingError`, `DependencyError`
- gRPC clients for ResourceMonitor and Engine services
- LanguageRuntime gRPC server with handlers for Pulumi CLI integration
- Protobuf serialization/deserialization with secret envelope handling
- Retry logic with exponential backoff for transient gRPC errors
- Proto file management via Julia Artifacts
- Documentation site via Documenter.jl
- CI via GitHub Actions

[Unreleased]: https://github.com/s-celles/Pulumi.jl/compare/v0.1.0...HEAD
