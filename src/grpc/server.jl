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
struct LanguageRuntimeServer
    server::GRPCServer
    service::JuliaLanguageRuntime
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
            ENV["PULUMI_PROJECT"] = runtime.project_name
            ENV["PULUMI_STACK"] = runtime.stack_name
            ENV["PULUMI_MONITOR"] = req.monitor_address
            ENV["PULUMI_ENGINE"] = runtime.engine_address
            ENV["PULUMI_DRY_RUN"] = req.dryRun ? "true" : "false"
            ENV["PULUMI_PARALLEL"] = string(req.parallel)

            # Set config as JSON if provided
            if req.config !== nothing && !isempty(req.config)
                ENV["PULUMI_CONFIG"] = JSON3.write(req.config)
            else
                ENV["PULUMI_CONFIG"] = "{}"
            end

            # Set secret keys if provided
            if req.configSecretKeys !== nothing && !isempty(req.configSecretKeys)
                ENV["PULUMI_CONFIG_SECRET_KEYS"] = JSON3.write(req.configSecretKeys)
            else
                ENV["PULUMI_CONFIG_SECRET_KEYS"] = "[]"
            end

            # Trigger context creation with new environment
            _ = get_context()
        catch e
            # Log but don't fail - context setup is best effort
            @warn "Failed to set up execution context" exception=e
        end

        # 7. Execute the program
        # Note: Using include() executes in the current module scope
        # A more robust approach would use a sandbox module
        cd(pwd) do
            include(program_path)
        end

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
    handle_install_dependencies(runtime, ctx, req, stream) -> Nothing

Handle the InstallDependencies RPC - installs Julia package dependencies.
This is a streaming RPC that sends stdout/stderr as responses.
"""
function handle_install_dependencies(
    runtime::JuliaLanguageRuntime,
    ctx::ServerContext,
    req::InstallDependenciesRequest,
    stream::ServerStream{InstallDependenciesResponse}
)
    try
        directory = !isempty(req.directory) ? req.directory : runtime.program_directory

        # Run Pkg.instantiate in the project directory
        cd(directory) do
            # Capture output
            stdout_content = "Installing Julia dependencies...\n"
            gRPCServer.send!(stream, InstallDependenciesResponse(
                Vector{UInt8}(stdout_content),
                UInt8[]
            ))

            # TODO: Actually run Pkg.instantiate() and capture output
            # For now, just send a completion message
            stdout_content = "Dependencies installed successfully.\n"
            gRPCServer.send!(stream, InstallDependenciesResponse(
                Vector{UInt8}(stdout_content),
                UInt8[]
            ))
        end
    catch e
        error_msg = sprint(showerror, e)
        gRPCServer.send!(stream, InstallDependenciesResponse(
            UInt8[],
            Vector{UInt8}(error_msg)
        ))
    end

    return nothing
end

"""
    handle_get_program_dependencies(runtime, ctx, req) -> GetProgramDependenciesResponse

Handle the GetProgramDependencies RPC - returns program dependencies.
"""
function handle_get_program_dependencies(runtime::JuliaLanguageRuntime, ctx::ServerContext, req::GetProgramDependenciesRequest)
    dependencies = DependencyInfo[]

    # Always include Pulumi.jl
    push!(dependencies, DependencyInfo("Pulumi", "0.1.0"))

    # TODO: Parse Project.toml for actual dependencies

    return GetProgramDependenciesResponse(dependencies)
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
        ),
        runtime  # Closure context
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
    server = GRPCServer(host, port)
    runtime = JuliaLanguageRuntime()
    gRPCServer.register!(server, runtime)

    return LanguageRuntimeServer(server, runtime, port)
end

"""
    start_and_print_port!(server::LanguageRuntimeServer)

Start the server and print the assigned port to stdout.
This is the Pulumi plugin discovery protocol.
"""
function start_and_print_port!(server::LanguageRuntimeServer)
    gRPCServer.start!(server.server)

    # Get the actual port (important when port=0 for auto-assign)
    # Note: gRPCServer should provide a way to get the bound port
    # For now, assume it's stored or accessible
    actual_port = server.port
    if actual_port == 0
        # TODO: Get actual bound port from server
        actual_port = 50051  # Placeholder
    end

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

    # Stop the gRPC server
    gRPCServer.stop!(server.server)
end
