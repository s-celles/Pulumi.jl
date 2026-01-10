#!/usr/bin/env julia
#
# Create Proto Artifact
#
# Packages proto files into a tarball for use as a Julia Artifact.
# Outputs the tarball and Artifacts.toml entry.
#
# Usage:
#   julia --project=. gen/create_proto_artifact.jl [version]
#
# Example:
#   julia --project=. gen/create_proto_artifact.jl v3.140.0
#
# This creates:
#   - artifacts/pulumi-protos-<version>.tar.gz
#   - Prints Artifacts.toml entry to add

using Pkg.Artifacts
using SHA

function main(args::Vector{String}=ARGS)
    repo_root = dirname(@__DIR__)
    proto_dir = joinpath(repo_root, "proto")
    artifacts_dir = joinpath(repo_root, "artifacts")

    # Get version from args or default
    version = isempty(args) ? "latest" : args[1]

    # Validate proto directory exists
    if !isdir(proto_dir)
        error("Proto directory not found: $proto_dir\nRun gen/download_protos.jl first.")
    end

    # Create artifacts directory
    mkpath(artifacts_dir)

    # Tarball filename
    tarball_name = "pulumi-protos-$(version).tar.gz"
    tarball_path = joinpath(artifacts_dir, tarball_name)

    println("=" ^ 60)
    println("Create Proto Artifact")
    println("=" ^ 60)
    println("  Version:    $version")
    println("  Source:     $proto_dir")
    println("  Output:     $tarball_path")
    println()

    # Create tarball using shell tar (simpler, no extra dependencies)
    println("Creating tarball...")
    run(`tar -czf $tarball_path -C $proto_dir .`)

    # Compute SHA256 of tarball
    println("Computing SHA256...")
    tarball_sha256 = open(tarball_path, "r") do io
        bytes2hex(sha256(io))
    end

    # Compute git-tree-sha1 of contents
    println("Computing git-tree-sha1...")
    tree_hash = create_artifact() do artifact_dir
        for item in readdir(proto_dir)
            src = joinpath(proto_dir, item)
            dst = joinpath(artifact_dir, item)
            cp(src, dst)
        end
    end

    # Get file size
    size_bytes = filesize(tarball_path)
    size_kb = round(size_bytes / 1024, digits=1)

    println()
    println("Done!")
    println("  Tarball:       $tarball_path")
    println("  Size:          $size_kb KB")
    println("  git-tree-sha1: $tree_hash")
    println("  sha256:        $tarball_sha256")
    println()
    println("=" ^ 60)
    println("Add to Artifacts.toml:")
    println("=" ^ 60)
    println()

    # Print Artifacts.toml entry
    println("""
[pulumi_protos]
git-tree-sha1 = "$tree_hash"

    [[pulumi_protos.download]]
    sha256 = "$tarball_sha256"
    url = "https://github.com/s-celles/Pulumi.jl/releases/download/$version/$tarball_name"
""")

    println()
    println("=" ^ 60)
    println("Next steps:")
    println("=" ^ 60)
    println("1. Upload $tarball_path to GitHub releases")
    println("2. Copy the above Artifacts.toml entry and update Artifacts.toml")
    println()

    return tarball_path, tree_hash, tarball_sha256
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
