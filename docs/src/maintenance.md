# SDK Maintenance Guide

This guide covers maintaining the Pulumi.jl SDK, with a focus on updating protocol buffer files when Pulumi releases new versions.

## Overview

Pulumi.jl communicates with the Pulumi engine via gRPC, which requires protocol buffer (proto) definitions. When Pulumi releases new versions, these proto files may change, requiring updates to the SDK.

Proto files are distributed as a **Julia Artifact** (defined in `Artifacts.toml`) and are not stored in the repository. This keeps the repo clean and ensures reproducible builds.

## Proto Update Workflow

### Quick Update (Latest Version)

To update proto files and regenerate Julia code in one command:

```bash
julia --project=. gen/download_protos.jl --generate
```

This downloads the latest proto files from the Pulumi master branch and regenerates the Julia bindings.

### Step-by-Step Update

For more control over the update process:

1. **Download proto files**:
   ```bash
   julia --project=. gen/download_protos.jl
   ```

2. **Review downloaded files**:
   ```bash
   ls -la proto/
   ```

3. **Regenerate Julia bindings**:
   ```bash
   julia --project=. gen/generate_protos.jl
   ```

4. **Run tests**:
   ```bash
   julia --project=. -e 'using Pkg; Pkg.test()'
   ```

5. **Commit changes**:
   ```bash
   git add src/grpc/proto/
   git commit -m "chore: update Pulumi proto files to latest"
   ```

### Updating to a Specific Version

To update to a specific Pulumi release:

```bash
# Download protos from a specific version tag
julia --project=. gen/download_protos.jl v3.140.0

# Or download and generate in one step
julia --project=. gen/download_protos.jl v3.140.0 --generate
```

## Artifact Management

Proto files are managed as a Julia Artifact. The artifact is defined in `Artifacts.toml` and downloaded automatically when running `gen/generate_protos.jl`.

### Updating the Artifact

When proto files change significantly (new Pulumi version), update the artifact:

1. **Download new proto files**:
   ```bash
   julia --project=. gen/download_protos.jl v3.150.0
   ```

2. **Create artifact tarball**:
   ```bash
   julia --project=. gen/create_proto_artifact.jl v3.150.0
   ```

3. **Upload tarball to GitHub releases**:
   - Go to the repository releases page
   - Create a new release or edit existing
   - Upload `artifacts/pulumi-protos-v3.150.0.tar.gz`

4. **Update Artifacts.toml** with the output from step 2

5. **Test the artifact**:
   ```bash
   # Remove local proto/ to force artifact usage
   rm -rf proto/
   julia --project=. gen/generate_protos.jl
   ```

### Local Development

For development, you can use local proto files instead of the artifact:

```bash
# Download protos locally
julia --project=. gen/download_protos.jl

# Generate from local proto/
julia --project=. gen/generate_protos.jl
```

The generation script prefers the artifact but falls back to `proto/` if available.

## Proto File Structure

### Downloaded Layout

```
proto/
├── language.proto      # Language runtime interface
├── resource.proto      # Resource monitor interface
├── engine.proto        # Engine communication
├── provider.proto      # Provider interface
├── plugin.proto        # Plugin metadata
└── pulumi/
    ├── alias.proto     # Resource aliases
    ├── callback.proto  # Callbacks
    ├── source.proto    # Source positions
    ├── plugin.proto    # Plugin details
    ├── provider.proto  # Provider details
    └── codegen/
        └── hcl.proto   # HCL codegen
```

### Generated Julia Code

Generated Julia bindings are placed in:

```
src/grpc/proto/
├── google/protobuf/    # Well-known types
└── pulumirpc/          # Pulumi RPC definitions
```

## Scripts Reference

### `gen/download_protos.jl`

Downloads proto files from the official Pulumi GitHub repository.

**Usage**:
```bash
julia --project=. gen/download_protos.jl [version] [--generate]
```

**Arguments**:
- `version`: Git reference (tag, branch, or commit). Default: `master`
- `--generate` or `-g`: Run code generation after download

**Examples**:
```bash
# Download latest
julia --project=. gen/download_protos.jl

# Download specific version
julia --project=. gen/download_protos.jl v3.140.0

# Download and generate
julia --project=. gen/download_protos.jl --generate
```

### `gen/generate_protos.jl`

Generates Julia code from proto files using ProtoBuf.jl.

**Usage**:
```bash
julia --project=. gen/generate_protos.jl
```

Proto source priority:
1. Julia Artifact (`pulumi_protos` from `Artifacts.toml`)
2. Local `proto/` directory (fallback)

### `gen/create_proto_artifact.jl`

Creates a tarball artifact from downloaded proto files.

**Usage**:
```bash
julia --project=. gen/create_proto_artifact.jl [version]
```

**Output**:
- `artifacts/pulumi-protos-<version>.tar.gz`
- Artifacts.toml entry to copy

## Troubleshooting

### Download Errors

If proto download fails with a 404 error:
- Verify the version tag exists in the Pulumi repository
- Some older versions may not have all proto files
- Try using a more recent version tag

### Generation Errors

If code generation fails:
- Ensure proto files are valid (not corrupted)
- Check that all required proto files are present
- Verify ProtoBuf.jl is installed (`using ProtoBuf`)

### Artifact Not Found

If the artifact cannot be downloaded:
- Check network connectivity
- Verify the URL in `Artifacts.toml` is accessible
- Fall back to local proto files: `julia --project=. gen/download_protos.jl`

### Test Failures After Update

If tests fail after updating protos:
1. Check if proto changes are breaking (new required fields, removed messages)
2. Review the Pulumi changelog for breaking changes
3. Update SDK code to accommodate proto changes
4. Consider pinning to an older proto version if changes are incompatible

## Version Compatibility

The SDK tracks ProtoBuf.jl version in `Project.toml`:

```toml
[compat]
ProtoBuf = "1"
```

This ensures consistent code generation across machines and time. The `Manifest.toml` locks the exact version used.

## When to Update

Consider updating proto files when:
- A new Pulumi version is released with important features
- You need access to new provider capabilities
- Bug fixes in the proto layer affect your use case

Proto updates are generally backward compatible, but always run tests after updating.
