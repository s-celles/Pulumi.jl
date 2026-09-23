# Main entry points for Pulumi.jl development.
#
# Run `just` to list the available recipes.

julia := env_var_or_default("JULIA", "julia")
plugin_dir := "bin/pulumi-language-julia"

# List the available recipes.
default:
    @just --list

# Resolve and install the project dependencies.
instantiate:
    {{julia}} --project=. -e 'using Pkg; Pkg.instantiate()'

# Run the test suite.
test:
    {{julia}} --project=. -e 'using Pkg; Pkg.test()'

# Run the test suite including the tests that need a real Pulumi CLI.
test-integration:
    PULUMI_TEST_INTEGRATION=true {{julia}} --project=. -e 'using Pkg; Pkg.test()'

# Run only the matching test items, by name or file, e.g.
# `just test-item "Secret envelope"`.
test-item pattern:
    {{julia}} --project=. -e 'using Pkg; Pkg.test(test_args=["{{pattern}}"])'

# Report test coverage.
coverage:
    {{julia}} --project=. -e 'using Pkg; Pkg.test(coverage=true)'

# Install the documentation environment.
docs-instantiate:
    {{julia}} --project=docs -e 'using Pkg; Pkg.instantiate()'

# Build the documentation (also writes docs/build/llms.txt and llms-full.txt).
docs: docs-instantiate
    {{julia}} --project=docs docs/make.jl

# Serve the built documentation at http://localhost:8000.
docs-serve: docs
    {{julia}} -e 'using Sockets; run(`python3 -m http.server 8000 --directory docs/build`)'

# Download the Pulumi proto files, e.g. `just proto-download v3.140.0`.
proto-download version="":
    {{julia}} --project=. gen/download_protos.jl {{version}}

# Generate the Julia protobuf bindings from the downloaded proto files.
proto-generate:
    {{julia}} --project=. gen/generate_protos.jl

# Package the proto files as a Julia artifact.
proto-artifact version="":
    {{julia}} --project=. gen/create_proto_artifact.jl {{version}}

# Build the Go language host plugin (output: bin/pulumi-language-julia/pulumi-language-julia).
plugin-build:
    cd {{plugin_dir}} && go build .

# Install the language host into ~/.pulumi/plugins so the Pulumi CLI finds it.
plugin-install: plugin-build
    #!/usr/bin/env bash
    set -euo pipefail
    version=$({{julia}} --project=. -e 'using TOML; print(TOML.parsefile("Project.toml")["version"])')
    dest="${PULUMI_HOME:-$HOME/.pulumi}/plugins/language-julia-v${version}"
    mkdir -p "$dest"
    cp {{plugin_dir}}/pulumi-language-julia "$dest/"
    printf 'resource: false\nname: julia\nversion: %s\n' "$version" > "$dest/PulumiPlugin.yaml"
    echo "Installed pulumi-language-julia v${version} into $dest"

# Run the Julia language host directly (prints the bound port on stdout).
plugin-run:
    {{julia}} --project=. src/bin/pulumi-language-julia

# Remove build outputs.
clean:
    rm -rf docs/build
    rm -f {{plugin_dir}}/pulumi-language-julia {{plugin_dir}}/pulumi-language-julia.exe
