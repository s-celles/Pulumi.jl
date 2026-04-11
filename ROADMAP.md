# Pulumi.jl Roadmap

> **Status**: This project is in early experimental development. APIs may change without notice.

---

## Milestone 0.1.0 — Foundation (Current)

**Goal**: Establish core SDK architecture with gRPC communication, resource model, and language runtime server.

### Completed

- [x] **Proto & Code Generation** — Proto files downloaded from Pulumi upstream, Julia bindings generated via ProtoBuf.jl, managed as Julia Artifacts (specs 002, 003)
- [x] **Core Types** — `Resource`, `CustomResource`, `ComponentResource`, `ProviderResource`, `ResourceOptions`, `URN`
- [x] **Output System** — `Output{T}` parametric type with `apply`, `all`, `secret`, `Unknown` sentinel
- [x] **Resource Registration** — `register_resource`, `component`, `register_outputs`, parallel registration
- [x] **Dependency Graph** — DAG with cycle detection, topological sort, automatic dependency extraction from Outputs
- [x] **Configuration** — `Config` type with typed accessors (`get_int`, `get_bool`, `get_float`, `get_object`), secret support
- [x] **Context Management** — `Context` struct, `get_stack`, `get_project`, `get_organization`, `is_dry_run`
- [x] **Stack Exports** — `export_value`, `export_secret`, `register_stack_outputs`
- [x] **Invoke** — `invoke` and `call` for provider functions
- [x] **Logging** — `log_debug`, `log_info`, `log_warn`, `log_error` via Engine gRPC
- [x] **Error Types** — `PulumiError`, `ResourceError`, `GRPCError`, `ConfigMissingError`, `DependencyError`
- [x] **gRPC Clients** — `MonitorClient` (RegisterResource, Invoke, ReadResource, SupportsFeature), `EngineClient` (Log, GetRootResource)
- [x] **gRPC Server** — `LanguageRuntime` service with handlers: Handshake, Run, GetPluginInfo, About, GetRequiredPlugins, InstallDependencies, GetProgramDependencies, RuntimeOptions
- [x] **Serialization** — Protobuf Struct/Value conversion, secret envelope handling
- [x] **Retry Logic** — Exponential backoff for transient gRPC errors
- [x] **CI/CD** — GitHub Actions for tests and Documenter.jl deployment
- [x] **Documentation Site** — Documenter.jl with guides and API reference

### Remaining

- [ ] **Docstrings** — Add docstrings to all public API functions (NFR-031, many `@docs` blocks currently unresolved)
- [ ] **InstallDependencies handler** — Actually run `Pkg.instantiate()` and capture output (TODO in server.jl:251)
- [ ] **GetProgramDependencies handler** — Parse `Project.toml` for real dependencies (TODO in server.jl:281)
- [ ] **Server port binding** — Retrieve actual bound port from gRPCServer (TODO in server.jl:408)
- [ ] **Test coverage** — Fill in integration test placeholders (component_test.jl, conformance_test.jl, pulumi_cli_test.jl)
- [ ] **Aqua.jl clean** — Resolve any remaining code quality warnings

---

## Milestone 0.2.0 — End-to-End with Pulumi CLI

**Goal**: Make `pulumi up` / `pulumi preview` / `pulumi destroy` work end-to-end with real providers.

- [ ] **`pulumi-language-julia` plugin binary** — Create a standalone executable or script that the Pulumi CLI can discover and launch (IR-003, IR-004)
- [ ] **Plugin discovery** — Register Julia as a Pulumi language plugin so `pulumi new` and `runtime: julia` in `Pulumi.yaml` work
- [ ] **`pulumi new` template** — Provide a `julia` project template for bootstrapping new Pulumi Julia projects
- [ ] **End-to-end integration tests** — Test full lifecycle (up/preview/destroy) against a real provider (e.g., `pulumi-docker` or `pulumi-random`)
- [ ] **Graceful shutdown** — Handle SIGINT/SIGTERM properly, report errors to engine before exit (NFR-012)
- [ ] **Preview mode** — Properly propagate unknown values through Outputs during `pulumi preview` (FR-025)
- [ ] **State management** — Ensure resource state is correctly maintained across up/destroy cycles (NFR-013)
- [ ] **Error propagation** — Surface provider errors with full context and actionable messages (NFR-011, NFR-033)

---

## Milestone 0.3.0 — Resource Options & Robustness

**Goal**: Full resource options support and production-grade reliability.

- [ ] **`parent` option** — Establish resource hierarchy, propagate to URN (FR-030)
- [ ] **`depends_on` option** — Wire explicit dependencies into RegisterResource requests (FR-031)
- [ ] **`protect` option** — Prevent accidental deletion (FR-032)
- [ ] **`provider` option** — Explicit provider selection (FR-033)
- [ ] **`aliases` option** — Support resource renaming/refactoring (FR-034)
- [ ] **`ignore_changes` option** — Skip specific property updates (FR-035)
- [ ] **`delete_before_replace`** — Delete old resource before creating replacement (FR-036)
- [ ] **`retain_on_delete`** — Remove from state without deleting (FR-037)
- [ ] **`custom_timeouts`** — Per-resource operation timeouts
- [ ] **Cross-platform testing** — Validate on macOS and Windows in CI (NFR-022)
- [ ] **Performance benchmarks** — Verify 1000+ resources without memory exhaustion (NFR-001), serialization <10ms (NFR-003), startup <2s (NFR-004)
- [ ] **80% test coverage** — Comprehensive unit + integration tests (NFR-040)

---

## Milestone 0.4.0 — Developer Experience

**Goal**: Make Pulumi.jl pleasant to use for Julia developers.

- [ ] **Typed resource wrappers** — Macro or function to define resources with typed inputs/outputs instead of raw `Dict{String, Any}`
- [ ] **`@pulumi` macro** — DSL for cleaner resource declaration syntax
- [ ] **REPL integration** — Preview resource graphs and outputs interactively
- [ ] **Better `show` methods** — Rich display for resources, outputs, and dependency graphs
- [ ] **Stack reference** — Read outputs from other stacks (`StackReference` type)
- [ ] **Transformations** — Resource transform callbacks for policy enforcement
- [ ] **Comprehensive documentation** — Tutorials, how-to guides, provider-specific examples (AWS, Azure, GCP, Docker)

---

## Milestone 0.5.0 — Code Generation (SDK Gen)

**Goal**: Auto-generate typed Julia packages from Pulumi provider schemas.

- [ ] **Schema parser** — Parse Pulumi provider JSON schemas (CG-001)
- [ ] **Struct generation** — Generate typed Julia structs for resource inputs and outputs (CG-002, CG-003)
- [ ] **Docstring generation** — Produce docstrings from schema descriptions (CG-004)
- [ ] **Enum generation** — Create `@enum` types from schema enums (CG-005)
- [ ] **Nested types** — Handle complex/nested schema types (CG-006)
- [ ] **Provider package template** — Generate full Julia packages (e.g., `PulumiAWS.jl`, `PulumiDocker.jl`)
- [ ] **CI for generated packages** — Automated regeneration when upstream schemas change

---

## Milestone 1.0.0 — Production Ready

**Goal**: Stable, registered, production-grade Julia SDK for Pulumi.

- [ ] **Register gRPCServer.jl** — Publish to Julia General registry (currently unregistered dependency)
- [ ] **Register Pulumi.jl** — Publish to Julia General registry (C-001)
- [ ] **Semantic versioning** — Stable public API with breaking change policy
- [ ] **Automation API** — Programmatic control of Pulumi stacks from Julia (no CLI required)
- [ ] **Dynamic providers** — Implement custom providers in Julia
- [ ] **Policy as Code** — Support Pulumi CrossGuard policies written in Julia
- [ ] **Async invoke** — Provider function invocations returning Outputs (FR-062)
- [ ] **Multi-language interop** — Consume component resources from other Pulumi SDKs
- [ ] **Security audit** — Review serialization, secret handling, and gRPC communication
- [ ] **SciML coding standards** — Full type stability compliance (NFR-042)
- [ ] **Logo & branding** — Project logo, badges, social preview image

---

## Future Ideas (Post 1.0)

- **Notebook integration** — Define infrastructure in Jupyter/Pluto notebooks
- **Visualization** — Render resource dependency graphs with Graphs.jl / GraphMakie.jl
- **Testing framework** — Unit testing helpers for Pulumi programs (mock providers)
- **IDE support** — Language server protocol integration for resource autocompletion
- **Package ecosystem** — Pre-built typed packages for major cloud providers (AWS, Azure, GCP, Kubernetes)

---

## Requirement Traceability

| Spec ID | Description | Milestone |
|---------|-------------|-----------|
| FR-001–006 | Core runtime & gRPC | 0.1.0 |
| FR-010–016 | Resource model | 0.1.0 |
| FR-020–025 | Output system | 0.1.0 / 0.2.0 |
| FR-030–037 | Resource options | 0.3.0 |
| FR-040–045 | Stack & configuration | 0.1.0 |
| FR-050–052 | Stack exports | 0.1.0 |
| FR-060–062 | Invoke functions | 0.1.0 / 1.0.0 |
| NFR-001–004 | Performance | 0.3.0 |
| NFR-010–013 | Reliability | 0.1.0 / 0.2.0 |
| NFR-020–023 | Compatibility | 0.2.0 / 0.3.0 |
| NFR-030–033 | Usability | 0.1.0 / 0.4.0 |
| NFR-040–042 | Maintainability | 0.3.0 / 1.0.0 |
| IR-001–004 | gRPC interfaces | 0.1.0 / 0.2.0 |
| IR-010–011 | Provider interface | 0.2.0 |
| CG-001–006 | Code generation | 0.5.0 |
