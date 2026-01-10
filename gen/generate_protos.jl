#!/usr/bin/env julia
#
# Proto Code Generation Script
#
# Generates Julia code from Pulumi proto files using ProtoBuf.jl's native protojl() function.
# No external protoc binary required - ProtoBuf.jl v1.0.0+ uses a pure Julia implementation.
#
# Proto files are sourced from:
#   1. Julia Artifact (pulumi_protos) - downloaded automatically
#   2. Local proto/ directory - for development/testing
#
# Usage:
#   julia --project=. gen/generate_protos.jl
#
# Or from Julia REPL:
#   include("gen/generate_protos.jl")

using ProtoBuf
using Pkg.Artifacts

"""
    get_proto_dir()

Get the proto directory path, preferring artifact over local directory.
Returns the artifact path if available, otherwise falls back to local proto/.
"""
function get_proto_dir()
    repo_root = dirname(@__DIR__)
    local_proto_dir = joinpath(repo_root, "proto")

    # Try to use artifact first
    artifacts_toml = joinpath(repo_root, "Artifacts.toml")
    if isfile(artifacts_toml)
        try
            artifact_path = artifact"pulumi_protos"
            if isdir(artifact_path)
                return artifact_path, :artifact
            end
        catch e
            # Artifact not available, fall back to local
        end
    end

    # Fall back to local proto directory
    if isdir(local_proto_dir)
        return local_proto_dir, :local
    end

    error("Proto files not found. Run: julia --project=. gen/download_protos.jl")
end

function main()
    # Get repository root (parent of gen/ directory)
    repo_root = dirname(@__DIR__)

    # Proto source and output directories
    proto_dir, source = get_proto_dir()
    output_dir = joinpath(repo_root, "src", "grpc", "proto")

    # Proto files to compile (relative to proto_dir)
    proto_files = [
        "language.proto",
        "resource.proto",
        "engine.proto",
        "provider.proto",
        "plugin.proto",
        "pulumi/plugin.proto",
        "pulumi/callback.proto",
        "pulumi/alias.proto",
        "pulumi/source.proto",
        "pulumi/provider.proto",
        "pulumi/codegen/hcl.proto",
    ]

    # Validate all proto files exist
    missing_files = filter(f -> !isfile(joinpath(proto_dir, f)), proto_files)
    if !isempty(missing_files)
        error("Missing proto files: $(join(missing_files, ", "))")
    end

    # Validate output directory is writable (create if needed)
    if !isdir(output_dir)
        try
            mkpath(output_dir)
        catch e
            error("Cannot create output directory: $output_dir - $(e)")
        end
    end

    # Test write permissions
    test_file = joinpath(output_dir, ".write_test")
    try
        write(test_file, "test")
        rm(test_file)
    catch e
        error("Output directory is not writable: $output_dir - $(e)")
    end

    # Progress output with platform info
    source_label = source == :artifact ? "artifact" : "local"
    println("=" ^ 60)
    println("Proto Code Generation")
    println("=" ^ 60)
    println("  Platform:         $(Sys.KERNEL) ($(Sys.MACHINE))")
    println("  Julia version:    $(VERSION)")
    println("  ProtoBuf.jl:      $(pkgversion(ProtoBuf))")
    println("  Proto source:     $source_label")
    println("  Input directory:  $proto_dir")
    println("  Output directory: $output_dir")
    println("  Proto files:      $(length(proto_files))")
    println()

    # Generate Julia code from proto files
    println("Generating Julia code from proto files...")
    ProtoBuf.protojl(
        proto_files,
        proto_dir,
        output_dir;
        include_vendored_wellknown_types=true,
        always_use_modules=true,
    )

    println()
    println("Done! Generated files are in: $output_dir")
    println("=" ^ 60)
end

# Run main when script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
