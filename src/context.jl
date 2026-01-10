"""
Execution context for Pulumi programs.

Per data-model.md:
- Context holds engine connection and stack information
- Created at program startup from environment variables
- Singleton per program execution
"""

using JSON3

"""
    Context

Execution context holding engine connection and stack information.

# Fields
- `project::String`: Project name from Pulumi.yaml
- `stack::String`: Current stack name
- `organization::String`: Organization name
- `is_dry_run::Bool`: Preview mode (true) or deploy (false)
- `parallel::Int`: Max parallel resource operations
- `monitor_address::String`: gRPC address for ResourceMonitor
- `engine_address::String`: gRPC address for Engine
"""
struct Context
    project::String
    stack::String
    organization::String
    is_dry_run::Bool
    parallel::Int
    monitor_address::String
    engine_address::String
    config::Dict{String, Any}
    config_secret_keys::Set{String}
    _monitor::MonitorClient
    _engine::EngineClient
end

# Global context singleton
const _CONTEXT = Ref{Union{Context, Nothing}}(nothing)

"""
    Context()

Create a Context from environment variables.

Environment variables:
- `PULUMI_PROJECT`: Project name
- `PULUMI_STACK`: Stack name
- `PULUMI_ORGANIZATION`: Organization name
- `PULUMI_DRY_RUN`: Preview mode flag
- `PULUMI_PARALLEL`: Max parallelism
- `PULUMI_MONITOR`: ResourceMonitor gRPC address
- `PULUMI_ENGINE`: Engine gRPC address
- `PULUMI_CONFIG`: JSON-encoded configuration
- `PULUMI_CONFIG_SECRET_KEYS`: Secret key names
"""
function Context()
    project = get(ENV, "PULUMI_PROJECT", "")
    stack = get(ENV, "PULUMI_STACK", "")
    organization = get(ENV, "PULUMI_ORGANIZATION", "")
    is_dry_run = lowercase(get(ENV, "PULUMI_DRY_RUN", "false")) in ("true", "1", "yes")
    parallel = parse(Int, get(ENV, "PULUMI_PARALLEL", "16"))
    monitor_address = get(ENV, "PULUMI_MONITOR", "")
    engine_address = get(ENV, "PULUMI_ENGINE", "")

    # Parse configuration
    config_json = get(ENV, "PULUMI_CONFIG", "{}")
    config = try
        JSON3.read(config_json, Dict{String, Any})
    catch
        Dict{String, Any}()
    end

    # Parse secret keys
    secret_keys_json = get(ENV, "PULUMI_CONFIG_SECRET_KEYS", "[]")
    secret_keys = try
        Set{String}(JSON3.read(secret_keys_json, Vector{String}))
    catch
        Set{String}()
    end

    # Create gRPC clients
    monitor = MonitorClient(monitor_address)
    engine = EngineClient(engine_address)

    # Connect if addresses are available
    if !isempty(monitor_address)
        connect!(monitor)
    end
    if !isempty(engine_address)
        connect!(engine)
    end

    Context(
        project,
        stack,
        organization,
        is_dry_run,
        parallel,
        monitor_address,
        engine_address,
        config,
        secret_keys,
        monitor,
        engine
    )
end

"""
    get_context() -> Context

Get the current execution context.
Creates a new context from environment if not already initialized.
"""
function get_context()::Context
    if _CONTEXT[] === nothing
        _CONTEXT[] = Context()
    end
    _CONTEXT[]
end

"""
    set_context!(ctx::Context)

Set the global execution context (for testing purposes).
"""
function set_context!(ctx::Context)
    _CONTEXT[] = ctx
end

"""
    reset_context!()

Reset the global context (for testing purposes).
"""
function reset_context!()
    if _CONTEXT[] !== nothing
        ctx = _CONTEXT[]
        disconnect!(ctx._monitor)
        disconnect!(ctx._engine)
        _CONTEXT[] = nothing
    end
end

"""
    get_stack() -> String

Get the current stack name.
"""
function get_stack()::String
    get_context().stack
end

"""
    get_project() -> String

Get the current project name.
"""
function get_project()::String
    get_context().project
end

"""
    get_organization() -> String

Get the current organization name.
"""
function get_organization()::String
    get_context().organization
end

"""
    is_dry_run() -> Bool

Check if running in preview/dry-run mode.
"""
function is_dry_run()::Bool
    get_context().is_dry_run
end

# Show method
function Base.show(io::IO, ctx::Context)
    print(io, "Context(project=\"", ctx.project, "\", stack=\"", ctx.stack, "\")")
end

function Base.show(io::IO, ::MIME"text/plain", ctx::Context)
    println(io, "Pulumi Context:")
    println(io, "  Project: ", ctx.project)
    println(io, "  Stack: ", ctx.stack)
    println(io, "  Organization: ", ctx.organization)
    println(io, "  Dry Run: ", ctx.is_dry_run)
    println(io, "  Parallel: ", ctx.parallel)
    println(io, "  Monitor: ", isempty(ctx.monitor_address) ? "(not connected)" : ctx.monitor_address)
    print(io, "  Engine: ", isempty(ctx.engine_address) ? "(not connected)" : ctx.engine_address)
end
