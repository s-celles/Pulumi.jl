"""
gRPC server for Pulumi LanguageRuntime service.

Implements the LanguageRuntime gRPC service that the Pulumi CLI connects to
for executing Julia infrastructure programs.

Per constitution's gRPC Protocol Fidelity principle:
- LanguageRuntime service: Handshake, Run, GetPluginInfo, About, etc.
"""

using gRPCServer
import gRPCServer: service_descriptor, ServiceDescriptor, MethodDescriptor, MethodType
import gRPCServer: ServerContext, ServerStream, GRPCServer

import TOML

# Import ProtoBuf for message encoding/decoding
import ProtoBuf as PB

# Use proto types (included at Pulumi module level)
using .pulumirpc: LanguageHandshakeRequest, LanguageHandshakeResponse
using .pulumirpc: RunRequest, RunResponse
using .pulumirpc: AboutRequest, AboutResponse
using .pulumirpc: GetRequiredPluginsRequest, GetRequiredPluginsResponse
using .pulumirpc: InstallDependenciesRequest, InstallDependenciesResponse
using .pulumirpc: GetProgramDependenciesRequest, GetProgramDependenciesResponse
using .pulumirpc: RuntimeOptionsRequest, RuntimeOptionsResponse
using .pulumirpc: PluginInfo, ProgramInfo, DependencyInfo, PluginDependency, RuntimeOptionPrompt
using .pulumirpc.google.protobuf: Empty

"""
    JuliaLanguageRuntime

The main service struct that implements the LanguageRuntime gRPC service.

Stores connection info received during Handshake for use during Run.
"""
mutable struct JuliaLanguageRuntime
    # Engine connection info (from Handshake)
    engine_address::String
    root_directory::String
    program_directory::String

    # State
    initialized::Bool

    JuliaLanguageRuntime() = new("", "", "", false)
end

"""
    LanguageRuntimeServer

Wrapper around GRPCServer that manages the LanguageRuntime service lifecycle.
"""
mutable struct LanguageRuntimeServer
    server::GRPCServer
    service::JuliaLanguageRuntime
    # Requested port; replaced by the port actually bound once the server is
    # started, which matters when port 0 was requested (ephemeral port).
    port::Int
end

# ============================================================================
# Handler Functions
# ============================================================================

"""
    handle_handshake(runtime, ctx, req) -> LanguageHandshakeResponse

Handle the Handshake RPC - stores engine address and directory info.
"""
function handle_handshake(runtime::JuliaLanguageRuntime, ctx::ServerContext, req::LanguageHandshakeRequest)
    # Validate request
    if isempty(req.engine_address)
        throw(gRPCServer.GRPCError(gRPCServer.StatusCode.INVALID_ARGUMENT, "engine_address is required"))
    end

    # Store connection info
    runtime.engine_address = req.engine_address
    runtime.root_directory = req.root_directory
    runtime.program_directory = req.program_directory
    runtime.initialized = true

    return LanguageHandshakeResponse()
end

"""
    handle_get_plugin_info(runtime, ctx, req) -> PluginInfo

Handle the GetPluginInfo RPC - returns plugin version.
"""
function handle_get_plugin_info(runtime::JuliaLanguageRuntime, ctx::ServerContext, req::Empty)
    # Return Pulumi.jl version
    # Note: In real implementation, use pkgversion(Pulumi)
    version = "0.1.0"
    return PluginInfo(version)
end

"""
    handle_run(runtime, ctx, req) -> RunResponse

Handle the Run RPC - executes the user's Pulumi program.
"""
function handle_run(runtime::JuliaLanguageRuntime, ctx::ServerContext, req::RunRequest)
    try
        # 1. Validate runtime is initialized
        if !runtime.initialized
            return RunResponse("Runtime not initialized - Handshake must be called first", true)
        end

        # 2. Determine entry point
        entry_point = if req.info !== nothing && !isempty(req.info.entry_point)
            req.info.entry_point
        elseif !isempty(req.program)
            req.program
        else
            "Pulumi.jl"  # Default entry point
        end

        # 3. Determine working directory
        pwd = !isempty(req.pwd) ? req.pwd : runtime.program_directory

        # 4. Build full path to program
        program_path = isabspath(entry_point) ? entry_point : joinpath(pwd, entry_point)

        # 5. Check program exists
        if !isfile(program_path)
            return RunResponse("Program not found: $program_path", false)
        end

        # 6. Set up execution context via environment variables
        # The Context() constructor will read these and create gRPC clients
        try
            # Reset any existing context
            reset_context!()

            # Set environment variables for Context creation
            ENV["PULUMI_PROJECT"] = req.project
            ENV["PULUMI_STACK"] = req.stack
            ENV["PULUMI_ORGANIZATION"] = req.organization
            ENV["PULUMI_MONITOR"] = req.monitor_address
            ENV["PULUMI_ENGINE"] = runtime.engine_address
            ENV["PULUMI_DRY_RUN"] = req.dryRun ? "true" : "false"
            ENV["PULUMI_PARALLEL"] = string(req.parallel)

            # Set config as JSON if provided
            if req.config !== nothing && !isempty(req.config)
                ENV["PULUMI_CONFIG"] = JSON.json(req.config)
            else
                ENV["PULUMI_CONFIG"] = "{}"
            end

            # Set secret keys if provided
            if req.configSecretKeys !== nothing && !isempty(req.configSecretKeys)
                ENV["PULUMI_CONFIG_SECRET_KEYS"] = JSON.json(req.configSecretKeys)
            else
                ENV["PULUMI_CONFIG_SECRET_KEYS"] = "[]"
            end

            # Trigger context creation with new environment
            _ = get_context()
        catch e
            # Log but don't fail - context setup is best effort
            @warn "Failed to set up execution context" exception=e
        end

        # 7. Execute the program and publish whatever it exported
        run_program(program_path)

        # 8. Cleanup gRPC clients
        try
            reset_context!()
        catch
            # Ignore cleanup errors
        end

        # 9. Success - return empty error
        return RunResponse("", false)

    catch e
        # Cleanup gRPC clients on error
        try
            reset_context!()
        catch
            # Ignore cleanup errors
        end

        # Return error message
        error_msg = sprint(showerror, e, catch_backtrace())
        return RunResponse(error_msg, false)
    end
end

"""
    handle_about(runtime, ctx, req) -> AboutResponse

Handle the About RPC - returns Julia runtime information.
"""
function handle_about(runtime::JuliaLanguageRuntime, ctx::ServerContext, req::AboutRequest)
    # Get Julia executable path
    executable = Base.julia_cmd().exec[1]

    # Get Julia version
    version = string(VERSION)

    # Build metadata
    metadata = Dict{String,String}(
        "pulumi_sdk_version" => "0.1.0",
        "os" => string(Sys.KERNEL),
        "arch" => string(Sys.ARCH),
        "word_size" => string(Sys.WORD_SIZE)
    )

    return AboutResponse(executable, version, metadata)
end

"""
    handle_get_required_plugins(runtime, ctx, req) -> GetRequiredPluginsResponse

Handle the GetRequiredPlugins RPC - returns required provider plugins.
"""
function handle_get_required_plugins(runtime::JuliaLanguageRuntime, ctx::ServerContext, req::GetRequiredPluginsRequest)
    # Initial implementation: return empty list
    # Providers are discovered at runtime
    return GetRequiredPluginsResponse(Vector{PluginDependency}())
end

"""
    resolve_program_directory(runtime, req) -> String

Determine the directory holding the Pulumi program's `Project.toml`.

The Pulumi CLI reports the location in several ways depending on the RPC, so
the first non-empty of the request's `ProgramInfo`, the request's own
directory fields and the directory captured during `Handshake` wins.
"""
function resolve_program_directory(runtime::JuliaLanguageRuntime, candidates::AbstractVector{<:AbstractString})
    for candidate in candidates
        isempty(candidate) || return String(candidate)
    end
    isempty(runtime.program_directory) || return runtime.program_directory
    return pwd()
end

"""
    manifest_versions(manifest_file) -> Dict{String, String}

Read the resolved package versions from a `Manifest.toml`.

Returns an empty dictionary when the manifest is absent or unreadable, so a
program that has not been instantiated yet still reports its dependencies.
"""
function manifest_versions(manifest_file::AbstractString)
    versions = Dict{String, String}()
    isfile(manifest_file) || return versions

    manifest = try
        TOML.parsefile(manifest_file)
    catch
        return versions
    end

    # Manifest format 2.0 nests the packages under `deps`; format 1.0 lists
    # them at the top level.
    entries = get(manifest, "deps", manifest)
    entries isa AbstractDict || return versions

    for (name, records) in entries
        records isa AbstractVector || continue
        for record in records
            record isa AbstractDict || continue
            haskey(record, "version") || continue
            versions[name] = string(record["version"])
            break
        end
    end

    return versions
end

"""
    project_dependencies(directory) -> Vector{DependencyInfo}

List the direct dependencies declared by the `Project.toml` in `directory`.

Versions are reported from the resolved `Manifest.toml` when one exists and
fall back to the `[compat]` bounds otherwise. An absent or malformed
`Project.toml` yields an empty list rather than an error: the Pulumi CLI uses
this RPC for reporting, and a failure here must not abort a deployment.
"""
function project_dependencies(directory::AbstractString)
    dependencies = DependencyInfo[]

    project_file = joinpath(directory, "Project.toml")
    isfile(project_file) || return dependencies

    project = try
        TOML.parsefile(project_file)
    catch
        return dependencies
    end

    deps = get(project, "deps", nothing)
    deps isa AbstractDict || return dependencies

    compat = get(project, "compat", Dict{String, Any}())
    versions = manifest_versions(joinpath(directory, "Manifest.toml"))

    for name in sort!(collect(keys(deps)))
        version = get(versions, name, "")
        if isempty(version) && compat isa AbstractDict
            version = string(get(compat, name, ""))
        end
        push!(dependencies, DependencyInfo(name, version))
    end

    return dependencies
end

"""
    pump_pipe(pipe, sink) -> Nothing

Forward everything written to `pipe` to `sink`, one chunk at a time, until the
pipe is exhausted.
"""
function pump_pipe(pipe::IO, sink)
    try
        while !eof(pipe)
            chunk = readavailable(pipe)
            isempty(chunk) || sink(Vector{UInt8}(chunk))
        end
    catch
        # The pipe is closed while the process tears down; there is nothing
        # left to forward.
    finally
        close(pipe)
    end
    return nothing
end

"""
    handle_install_dependencies(runtime, ctx, req, stream) -> Nothing

Handle the InstallDependencies RPC - installs Julia package dependencies.

Runs `Pkg.instantiate()` for the program's environment in a separate Julia
process, so the language host's own environment is left untouched, and streams
the subprocess output back to the CLI as it is produced.
"""
function handle_install_dependencies(
    runtime::JuliaLanguageRuntime,
    ctx::ServerContext,
    req::InstallDependenciesRequest,
    stream::ServerStream{InstallDependenciesResponse}
)
    # The pipes are drained by two concurrent tasks, so sending must be
    # serialized.
    send_lock = ReentrantLock()
    emit = function (bytes::Vector{UInt8}, is_stderr::Bool)
        isempty(bytes) && return nothing
        response = is_stderr ?
            InstallDependenciesResponse(UInt8[], bytes) :
            InstallDependenciesResponse(bytes, UInt8[])
        lock(send_lock) do
            gRPCServer.send!(stream, response)
        end
        return nothing
    end

    try
        info_directory = req.info !== nothing ? req.info.program_directory : ""
        directory = resolve_program_directory(runtime, [req.directory, info_directory])

        if !isdir(directory)
            throw(ArgumentError("Program directory not found: $directory"))
        end

        emit(Vector{UInt8}("Installing Julia dependencies in $directory\n"), false)

        script = "using Pkg; Pkg.instantiate()"
        # `JULIA_LOAD_PATH` is pinned so the subprocess sees the program's
        # environment plus the standard library, whatever load path the host
        # happens to run under (`Pkg.test`, for instance, restricts it and
        # would leave `Pkg` itself unreachable).
        command = addenv(
            `$(Base.julia_cmd()) --project=$directory --startup-file=no --color=no -e $script`,
            "JULIA_LOAD_PATH" => "@:@stdlib",
            "JULIA_PROJECT" => nothing,
        )

        stdout_pipe = Pipe()
        stderr_pipe = Pipe()
        process = run(pipeline(command; stdout = stdout_pipe, stderr = stderr_pipe); wait = false)
        close(stdout_pipe.in)
        close(stderr_pipe.in)

        # Drain both pipes concurrently so a chatty subprocess cannot fill a
        # pipe buffer and deadlock.
        stdout_pump = @async pump_pipe(stdout_pipe, chunk -> emit(chunk, false))
        stderr_pump = @async pump_pipe(stderr_pipe, chunk -> emit(chunk, true))

        wait(process)
        wait(stdout_pump)
        wait(stderr_pump)

        if success(process)
            emit(Vector{UInt8}("Dependencies installed successfully.\n"), false)
        else
            emit(Vector{UInt8}("Pkg.instantiate() failed with exit code $(process.exitcode).\n"), true)
        end
    catch e
        emit(Vector{UInt8}(sprint(showerror, e) * "\n"), true)
    end

    return nothing
end

"""
    handle_get_program_dependencies(runtime, ctx, req) -> GetProgramDependenciesResponse

Handle the GetProgramDependencies RPC - returns program dependencies.

Reports the direct dependencies declared in the program's `Project.toml`.
Transitive dependencies are not reported yet, so `req.transitiveDependencies`
is currently ignored.
"""
function handle_get_program_dependencies(runtime::JuliaLanguageRuntime, ctx::ServerContext, req::GetProgramDependenciesRequest)
    info_directory = req.info !== nothing ? req.info.program_directory : ""
    directory = resolve_program_directory(runtime, [info_directory, req.pwd])

    return GetProgramDependenciesResponse(project_dependencies(directory))
end

"""
    handle_runtime_options(runtime, ctx, req) -> RuntimeOptionsResponse

Handle the RuntimeOptions RPC - returns configurable runtime options.
"""
function handle_runtime_options(runtime::JuliaLanguageRuntime, ctx::ServerContext, req::RuntimeOptionsRequest)
    # Return empty options for now
    return RuntimeOptionsResponse(Vector{RuntimeOptionPrompt}())
end

# ============================================================================
# Service Descriptor
# ============================================================================

"""
    service_descriptor(runtime::JuliaLanguageRuntime) -> ServiceDescriptor

Create the gRPCServer service descriptor for LanguageRuntime.
"""
function gRPCServer.service_descriptor(runtime::JuliaLanguageRuntime)
    ServiceDescriptor(
        "pulumirpc.LanguageRuntime",
        Dict{String,MethodDescriptor}(
            "Handshake" => MethodDescriptor(
                "Handshake",
                MethodType.UNARY,
                LanguageHandshakeRequest,
                LanguageHandshakeResponse,
                (ctx, req) -> handle_handshake(runtime, ctx, req)
            ),
            "Run" => MethodDescriptor(
                "Run",
                MethodType.UNARY,
                RunRequest,
                RunResponse,
                (ctx, req) -> handle_run(runtime, ctx, req)
            ),
            "GetPluginInfo" => MethodDescriptor(
                "GetPluginInfo",
                MethodType.UNARY,
                Empty,
                PluginInfo,
                (ctx, req) -> handle_get_plugin_info(runtime, ctx, req)
            ),
            "About" => MethodDescriptor(
                "About",
                MethodType.UNARY,
                AboutRequest,
                AboutResponse,
                (ctx, req) -> handle_about(runtime, ctx, req)
            ),
            "GetRequiredPlugins" => MethodDescriptor(
                "GetRequiredPlugins",
                MethodType.UNARY,
                GetRequiredPluginsRequest,
                GetRequiredPluginsResponse,
                (ctx, req) -> handle_get_required_plugins(runtime, ctx, req)
            ),
            "InstallDependencies" => MethodDescriptor(
                "InstallDependencies",
                MethodType.SERVER_STREAMING,
                InstallDependenciesRequest,
                InstallDependenciesResponse,
                (ctx, req, stream) -> handle_install_dependencies(runtime, ctx, req, stream)
            ),
            "GetProgramDependencies" => MethodDescriptor(
                "GetProgramDependencies",
                MethodType.UNARY,
                GetProgramDependenciesRequest,
                GetProgramDependenciesResponse,
                (ctx, req) -> handle_get_program_dependencies(runtime, ctx, req)
            ),
            "RuntimeOptions" => MethodDescriptor(
                "RuntimeOptions",
                MethodType.UNARY,
                RuntimeOptionsRequest,
                RuntimeOptionsResponse,
                (ctx, req) -> handle_runtime_options(runtime, ctx, req)
            )
        )
        # The handlers above already close over `runtime`; the descriptor's
        # third argument is the reflection file descriptor, which Pulumi.jl
        # does not publish.
    )
end

# ============================================================================
# Server Lifecycle
# ============================================================================

"""
    create_language_runtime_server(host::String="127.0.0.1", port::Int=0) -> LanguageRuntimeServer

Create a new LanguageRuntime gRPC server.

# Arguments
- `host`: Host address to bind to (default: "127.0.0.1")
- `port`: Port to bind to (default: 0 for auto-assign)

# Returns
- `LanguageRuntimeServer` instance ready to be started
"""
function create_language_runtime_server(host::String="127.0.0.1", port::Int=0)
    # GRPCServer rejects port 0 at construction, so an ephemeral port is
    # requested by building the server with a placeholder and lowering the
    # port to 0 before `start!` binds it.
    server = port == 0 ? GRPCServer(host, 1) : GRPCServer(host, port)
    server.port = port

    runtime = JuliaLanguageRuntime()
    gRPCServer.register!(server, runtime)

    return LanguageRuntimeServer(server, runtime, port)
end

"""
    start_and_print_port!(server::LanguageRuntimeServer)

Start the server and print the assigned port to stdout.
This is the Pulumi plugin discovery protocol: the CLI launches the plugin and
reads the port to connect to from the first line of its stdout.

Returns the port that was actually bound, which is the kernel-assigned port
when the server was created with `port = 0`.
"""
function start_and_print_port!(server::LanguageRuntimeServer)
    gRPCServer.start!(server.server)

    # With port 0 the real port is only known once the backend is listening.
    actual_port = Int(gRPCServer.HTTP.port(server.server))
    server.port = actual_port

    # Print port to stdout for Pulumi CLI discovery
    println(actual_port)
    flush(stdout)

    return actual_port
end

"""
    run_server(server::LanguageRuntimeServer)

Run the server (blocking until shutdown).
"""
function run_server(server::LanguageRuntimeServer)
    gRPCServer.run(server.server)
end

"""
    stop_server!(server::LanguageRuntimeServer)

Stop the server gracefully, cleaning up all resources.

This function:
1. Disconnects all gRPC clients (MonitorClient, EngineClient)
2. Resets the global context
3. Stops the gRPC server
"""
function stop_server!(server::LanguageRuntimeServer)
    # Clean up global context and clients
    try
        reset_context!()
    catch
        # Ignore cleanup errors
    end

    # Stop the gRPC server. Stopping a server that was never started, or
    # stopping twice, is a no-op: shutdown can be reached from the normal path
    # and from the atexit hook installed by `run_language_host`.
    try
        gRPCServer.stop!(server.server)
    catch e
        e isa gRPCServer.InvalidServerStateError || rethrow()
    end

    return nothing
end

"""
    run_language_host(; host="127.0.0.1", port=0) -> Int

Run the Pulumi language host until it is asked to shut down, and return the
process exit code.

This is what `bin/pulumi-language-julia` executes. It starts the
`LanguageRuntime` server, announces the bound port on stdout as the Pulumi
plugin protocol requires, and serves until the process is interrupted.

Neither `SIGINT` (Ctrl-C) nor `SIGTERM` unwinds the stack in a way the server
loop can catch reliably, but Julia runs `atexit` hooks for both, so shutdown is
installed there. The hook is idempotent, so the normal return path can stop the
server too without stopping it twice.

A failure is logged to the engine, when one is connected, before returning a
non-zero exit code.
"""
function run_language_host(; host::String = "127.0.0.1", port::Int = 0)::Int
    server = create_language_runtime_server(host, port)

    stopped = Ref(false)
    shutdown_lock = ReentrantLock()
    shutdown = function ()
        lock(shutdown_lock) do
            stopped[] && return nothing
            stopped[] = true
            try
                stop_server!(server)
            catch e
                @debug "Error while stopping the language host" exception = e
            end
            return nothing
        end
    end

    atexit(shutdown)

    start_and_print_port!(server)

    status = 0
    try
        run_server(server)
    catch e
        if e isa InterruptException
            # A requested shutdown, not a failure.
        else
            status = 1
            # Reporting must not itself throw: a signal can arrive while the
            # failure is being logged.
            try
                @error "Language host failed" exception = (e, catch_backtrace())
                # Best effort: the engine is only reachable once Handshake ran.
                log_error("Julia language host failed: " * sprint(showerror, e))
            catch
                # No engine connected, or the process is already going down.
            end
        end
    finally
        shutdown()
    end

    return status
end
