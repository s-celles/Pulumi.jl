# Language Host

The *language host* is the process the Pulumi CLI launches to run a Julia
program. It is a gRPC server implementing Pulumi's `LanguageRuntime` service:
the CLI asks it to install dependencies, report the program's dependencies and
finally execute the program against a resource monitor.

Most users never start it by hand — the Pulumi CLI does. This page describes
what it does, which is useful when debugging a deployment or working on
Pulumi.jl itself.

## Starting the host

```julia
using Pulumi

exit(run_language_host())
```

[`run_language_host`](@ref) creates the server, announces its port, serves until
the process is asked to stop and returns the process exit code. The repository
ships exactly that as an executable script:

```bash
julia --project=. src/bin/pulumi-language-julia
```

The individual steps are available when you need finer control:

```julia
server = create_language_runtime_server("127.0.0.1", 0)
port = start_and_print_port!(server)   # prints the port on stdout
run_server(server)                     # blocks until shutdown
stop_server!(server)
```

### Port discovery

The Pulumi plugin protocol is deliberately simple: the CLI starts the plugin,
reads a port number from the first line of its standard output and connects
there over gRPC.

Passing `port = 0` — the default — asks the kernel for an unused port, which is
what the CLI expects. [`start_and_print_port!`](@ref) resolves the port that was
actually bound, records it on the server and prints it:

```julia
server = create_language_runtime_server("127.0.0.1", 0)
port = start_and_print_port!(server)
@assert server.port == port   # the real port, not the requested 0
```

Pass an explicit port instead when you want to attach a debugger or a gRPC
client such as `grpcurl` to a known address.

!!! note
    Anything else the host writes to standard output would be parsed as the
    port, so a Pulumi program should log through [`log_info`](@ref) and friends
    rather than `println`.

### Shutdown

The host stops cleanly on both `SIGINT` (Ctrl-C) and `SIGTERM`, which is what a
supervisor or the Pulumi CLI sends when a deployment is cancelled. In both
cases the gRPC server is stopped, the resource monitor and engine clients are
disconnected and the port is released before the process exits, with the
conventional `130` and `143` exit codes.

Neither signal unwinds the stack in a way the serving loop can catch reliably,
so [`run_language_host`](@ref) installs the shutdown as an `atexit` hook, which
Julia runs for both. The hook is idempotent, so returning normally from
`run_server` shuts the server down exactly once as well.

[`stop_server!`](@ref) is safe to call on a server that was never started, or
more than once.

!!! warning
    A signal that arrives while Julia is still JIT-compiling the serving loop —
    the first few seconds after the port is announced — leaves the process
    wedged: the `atexit` hooks never run and the port is never released. This is
    a Julia-level hazard rather than something the host can guard against.
    Shipping the plugin as a sysimage would close that window.

## Installing the plugin

Build the Go host and install it where the Pulumi CLI looks for plugins:

```bash
just plugin-install
```

That puts `pulumi-language-julia` in `~/.pulumi/plugins/language-julia-v<version>/`
(or under `$PULUMI_HOME`), where `pulumi plugin ls` will list it:

```console
$ pulumi plugin ls
NAME   KIND      VERSION  SIZE   INSTALLED  LAST USED
julia  language  0.1.0    20 MB  now        now
```

The CLI also accepts an executable named `pulumi-language-julia` found on
`PATH`, which is handy while working on the host itself, but it prints a
warning on every run.

A project then selects it through `Pulumi.yaml`:

```yaml
name: my-project
runtime: julia
```

and the program lives in `main.jl` next to a `Project.toml` that depends on
Pulumi.jl. `pulumi preview`, `pulumi up` and `pulumi destroy` then work as they
do for any other language.

## Running a program

A program must be executed through [`run_program`](@ref), never `include`d
directly. `run_program` registers the stack's root `pulumi:pulumi:Stack`
resource before the program runs — the engine parents the program's resources
to it — and publishes the exported values as stack outputs once the program
finishes. A program that is merely `include`d registers its resources but
reports no outputs at all, and `pulumi stack output` comes back empty.

Both hosts do this: the Go host invokes
`julia --project=. -e 'using Pulumi; Pulumi.run_program("main.jl")'`, and the
Julia host's `Run` handler calls the same function.

## Implemented RPCs

| RPC | Behaviour |
|-----|-----------|
| `Handshake` | Stores the engine address and the root/program directories |
| `Run` | Runs the program through `run_program` and returns its error, if any |
| `GetPluginInfo` | Reports the Pulumi.jl version |
| `About` | Reports the Julia executable, version and platform |
| `GetRequiredPlugins` | Returns an empty list; providers are discovered at runtime |
| `InstallDependencies` | Runs `Pkg.instantiate()` for the program's environment |
| `GetProgramDependencies` | Reports the program's direct dependencies |
| `RuntimeOptions` | Returns no configurable options |

### InstallDependencies

`pulumi install`, and the automatic install performed by `pulumi up`, reach this
RPC. Pulumi.jl runs `Pkg.instantiate()` for the program's `Project.toml` **in a
separate Julia process**, so resolving the program's environment never disturbs
the environment the language host itself runs in. The subprocess's standard
output and error are streamed back to the CLI as they are produced, which is
what makes a long precompilation visible in the terminal.

A failure is reported on the stream's `stderr` together with the exit code; it
does not raise a gRPC error, so the CLI shows the resolver's own message.

### GetProgramDependencies

Reports the direct dependencies declared under `[deps]` in the program's
`Project.toml`. Versions come from the resolved `Manifest.toml` when the program
has been instantiated, and fall back to the `[compat]` bounds otherwise. A
program without a `Project.toml` reports no dependencies rather than failing.

Transitive dependencies are not reported yet, so the request's
`transitiveDependencies` flag is currently ignored.

### Run

`Run` sets the environment the program observes before including it:

| Variable | Source |
|----------|--------|
| `PULUMI_PROJECT` | `RunRequest.project` |
| `PULUMI_STACK` | `RunRequest.stack` |
| `PULUMI_ORGANIZATION` | `RunRequest.organization` |
| `PULUMI_MONITOR` | `RunRequest.monitor_address` |
| `PULUMI_ENGINE` | The engine address from `Handshake` |
| `PULUMI_DRY_RUN` | `RunRequest.dryRun` |
| `PULUMI_PARALLEL` | `RunRequest.parallel` |
| `PULUMI_CONFIG` | `RunRequest.config`, as JSON |
| `PULUMI_CONFIG_SECRET_KEYS` | `RunRequest.configSecretKeys`, as JSON |

[`Config`](@ref), [`get_stack`](@ref), [`get_project`](@ref),
[`get_organization`](@ref) and [`is_dry_run`](@ref) all read the context built
from these variables, which is why the same program works unchanged under
`pulumi preview` and `pulumi up`.

See the [Language Runtime Server](@ref) section of the API reference for the
functions mentioned here.
