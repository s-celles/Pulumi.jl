# Shared setup for the test items.
#
# TestItemRunner runs every `@testitem` in its own module, so anything shared
# lives here and is reached through the module name, for example
# `TestSupport.with_fake_engine`.

@testmodule TestSupport begin

using Test
using Sockets
using Pulumi
import gRPCServer
import gRPCServer: ServiceDescriptor, MethodDescriptor, MethodType, ServerContext

# ---------------------------------------------------------------------------
# An in-process stand-in for the Pulumi engine
#
# It serves the two gRPC services a Pulumi program talks to — `ResourceMonitor`
# and `Engine` — so the tests exercise the real client stack: serialization,
# the gRPC round trip and response handling. It records every request it
# receives so tests can assert on what the program actually sent.
# ---------------------------------------------------------------------------

const PB_ = Pulumi.pulumirpc

"""
    FakeEngine

Records the requests a Pulumi program sends and answers them the way the real
engine would.

# Fields
- `registrations`: every `RegisterResource` request, in arrival order
- `outputs`: every `RegisterResourceOutputs` request, in arrival order
- `logs`: every `Log` request, in arrival order
- `invokes`: every `Invoke` request, in arrival order
- `invoke_results`: what `Invoke` returns, keyed by token; a token with no
  entry comes back with the request's own arguments
- `root_urn`: the URN returned by `GetRootResource`. It defaults to empty,
  which is what a real engine returns: the root stack resource is registered by
  the SDK, not reported by the engine.
"""
mutable struct FakeEngine
    registrations::Vector{PB_.RegisterResourceRequest}
    outputs::Vector{PB_.RegisterResourceOutputsRequest}
    logs::Vector{PB_.LogRequest}
    invokes::Vector{PB_.ResourceInvokeRequest}
    invoke_results::Dict{String, Dict{String, Any}}
    root_urn::String
    # host:port the fake engine listens on, filled in by `with_fake_engine`.
    address::String
    lock::ReentrantLock

    FakeEngine(; root_urn::String = "") =
        new(PB_.RegisterResourceRequest[], PB_.RegisterResourceOutputsRequest[],
            PB_.LogRequest[], PB_.ResourceInvokeRequest[],
            Dict{String, Dict{String, Any}}(), root_urn, "", ReentrantLock())
end

"""
    fake_urn(engine, request) -> String

Build the URN the engine would assign to a freshly registered resource.
"""
function fake_urn(request::PB_.RegisterResourceRequest)
    return string("urn:pulumi:dev::test-project::", request.var"#type", "::", request.name)
end

function handle_register_resource(engine::FakeEngine, ::ServerContext, request::PB_.RegisterResourceRequest)
    lock(engine.lock) do
        push!(engine.registrations, request)
    end

    # Echo the inputs back as outputs, which is what a provider does for
    # properties it does not compute.
    return PB_.RegisterResourceResponse(
        fake_urn(request),
        string("id-", request.name),
        request.object,
        false,
        String[],
        Dict{String, PB_.var"RegisterResourceResponse.PropertyDependencies"}(),
        PB_.Result.SUCCESS,
    )
end

function handle_register_resource_outputs(engine::FakeEngine, ::ServerContext, request::PB_.RegisterResourceOutputsRequest)
    lock(engine.lock) do
        push!(engine.outputs, request)
    end
    return Pulumi.pulumirpc.google.protobuf.Empty()
end

function handle_invoke(engine::FakeEngine, ::ServerContext, request::PB_.ResourceInvokeRequest)
    lock(engine.lock) do
        push!(engine.invokes, request)
    end

    # Without a canned result, echo the arguments back: enough for a caller to
    # check that the invocation reached the monitor.
    result = get(engine.invoke_results, request.tok, nothing)
    returned = result === nothing ? request.args : Pulumi.dict_to_struct(result)
    return PB_.InvokeResponse(returned, PB_.CheckFailure[])
end

function handle_log(engine::FakeEngine, ::ServerContext, request::PB_.LogRequest)
    lock(engine.lock) do
        push!(engine.logs, request)
    end
    return Pulumi.pulumirpc.google.protobuf.Empty()
end

function handle_get_root_resource(engine::FakeEngine, ::ServerContext, ::PB_.GetRootResourceRequest)
    return PB_.GetRootResourceResponse(engine.root_urn)
end

function gRPCServer.service_descriptor(engine::FakeEngine)
    return ServiceDescriptor(
        "pulumirpc.ResourceMonitor",
        Dict{String, MethodDescriptor}(
            "RegisterResource" => MethodDescriptor(
                "RegisterResource", MethodType.UNARY,
                PB_.RegisterResourceRequest, PB_.RegisterResourceResponse,
                (ctx, req) -> handle_register_resource(engine, ctx, req),
            ),
            "RegisterResourceOutputs" => MethodDescriptor(
                "RegisterResourceOutputs", MethodType.UNARY,
                PB_.RegisterResourceOutputsRequest, Pulumi.pulumirpc.google.protobuf.Empty,
                (ctx, req) -> handle_register_resource_outputs(engine, ctx, req),
            ),
            "Invoke" => MethodDescriptor(
                "Invoke", MethodType.UNARY,
                PB_.ResourceInvokeRequest, PB_.InvokeResponse,
                (ctx, req) -> handle_invoke(engine, ctx, req),
            ),
        ),
    )
end

"""
    EngineService(engine)

Wrapper exposing `FakeEngine` as the `pulumirpc.Engine` service, which is a
separate service from `ResourceMonitor` and needs its own descriptor.
"""
struct EngineService
    engine::FakeEngine
end

function gRPCServer.service_descriptor(service::EngineService)
    engine = service.engine
    return ServiceDescriptor(
        "pulumirpc.Engine",
        Dict{String, MethodDescriptor}(
            "Log" => MethodDescriptor(
                "Log", MethodType.UNARY,
                PB_.LogRequest, Pulumi.pulumirpc.google.protobuf.Empty,
                (ctx, req) -> handle_log(engine, ctx, req),
            ),
            "GetRootResource" => MethodDescriptor(
                "GetRootResource", MethodType.UNARY,
                PB_.GetRootResourceRequest, PB_.GetRootResourceResponse,
                (ctx, req) -> handle_get_root_resource(engine, ctx, req),
            ),
        ),
    )
end

"""
    stack_urn(project="test-project", stack="dev") -> String

The URN the fake engine assigns to the root `pulumi:pulumi:Stack` resource.
"""
stack_urn(project::String = "test-project", stack::String = "dev") =
    "urn:pulumi:$(stack)::$(project)::pulumi:pulumi:Stack::$(project)-$(stack)"

"""
    with_fake_engine(f; project="test-project", stack="dev")

Start a fake engine, point the Pulumi context at it through the environment the
language host would set, run `f(engine)` and tear everything down again.
"""
function with_fake_engine(f; project::String = "test-project", stack::String = "dev")
    engine = FakeEngine()

    server = gRPCServer.GRPCServer("127.0.0.1", 1)
    server.port = 0  # ephemeral
    gRPCServer.register!(server, engine)
    gRPCServer.register!(server, EngineService(engine))
    gRPCServer.start!(server)
    address = string("127.0.0.1:", gRPCServer.HTTP.port(server))
    engine.address = address

    saved = Dict(key => get(ENV, key, nothing) for key in (
        "PULUMI_PROJECT", "PULUMI_STACK", "PULUMI_MONITOR", "PULUMI_ENGINE",
        "PULUMI_CONFIG", "PULUMI_CONFIG_SECRET_KEYS", "PULUMI_DRY_RUN",
    ))

    try
        Pulumi.reset_context!()
        ENV["PULUMI_PROJECT"] = project
        ENV["PULUMI_STACK"] = stack
        ENV["PULUMI_MONITOR"] = address
        ENV["PULUMI_ENGINE"] = address
        ENV["PULUMI_CONFIG"] = "{}"
        ENV["PULUMI_CONFIG_SECRET_KEYS"] = "[]"
        ENV["PULUMI_DRY_RUN"] = "false"

        return f(engine)
    finally
        Pulumi.reset_context!()
        for (key, value) in saved
            value === nothing ? delete!(ENV, key) : (ENV[key] = value)
        end
        try
            gRPCServer.stop!(server)
        catch
            # Already stopped.
        end
    end
end

# ---------------------------------------------------------------------------
# General test helpers
# ---------------------------------------------------------------------------

"""
    collect_stream(T) -> (stream, sent, closed)

Build a `ServerStream{T}` that records every message sent through it, so a
streaming handler can be exercised without a live gRPC connection.
"""
function collect_stream(::Type{T}) where {T}
    sent = T[]
    closed = Ref(false)
    stream = Pulumi.ServerStream{T}(
        (message, _compress) -> (push!(sent, message); nothing),
        () -> (closed[] = true; nothing),
    )
    return stream, sent, closed
end

"""
    capture_stdout(f) -> (result, text)

Run `f`, capturing anything it writes to stdout.
"""
function capture_stdout(f)
    pipe = Pipe()
    Base.link_pipe!(pipe; reader_supports_async = true, writer_supports_async = true)
    result = try
        redirect_stdout(f, pipe)
    finally
        close(pipe.in)
    end
    return result, String(read(pipe))
end

"""
    free_port() -> Int

Ask the kernel for a free TCP port and release it again.
"""
function free_port()
    server = Sockets.listen(Sockets.localhost, 0)
    port = Sockets.getsockname(server)[2]
    close(server)
    return Int(port)
end

# ---------------------------------------------------------------------------
# Resource option helpers
# ---------------------------------------------------------------------------

const Alias = Pulumi.pulumirpc.Alias
const CustomTimeouts = Pulumi.pulumirpc.var"RegisterResourceRequest.CustomTimeouts"

"""
    base_request(; kwargs...) -> Dict{String, Any}

A minimal valid `RegisterResource` request dict, with `kwargs` merged in.
"""
function base_request(; kwargs...)
    request = Dict{String, Any}(
        "type" => "aws:s3/bucket:Bucket",
        "name" => "my-bucket",
        "object" => Dict{String, Any}(),
    )
    for (key, value) in kwargs
        request[string(key)] = value
    end
    return request
end

end
