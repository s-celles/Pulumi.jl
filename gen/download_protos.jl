#!/usr/bin/env julia
#
# Proto File Download Script
#
# Downloads Pulumi proto files from the official GitHub repository.
# Uses Julia's Downloads stdlib - no external dependencies required.
#
# Usage:
#   julia --project=. gen/download_protos.jl              # Download latest (master)
#   julia --project=. gen/download_protos.jl v3.100.0     # Download specific version
#   julia --project=. gen/download_protos.jl --generate   # Download and generate Julia code
#   julia --project=. gen/download_protos.jl v3.100.0 --generate
#
# Or from Julia REPL:
#   include("gen/download_protos.jl")

using Downloads

# GitHub raw content base URL
const GITHUB_BASE_URL = "https://raw.githubusercontent.com/pulumi/pulumi"

# Proto file manifest: (remote_path, local_path)
# Maps Pulumi repo paths to our local directory structure
const PROTO_FILES = [
    # Root-level protos (downloaded from proto/pulumi/ in Pulumi repo)
    ("proto/pulumi/language.proto", "language.proto"),
    ("proto/pulumi/resource.proto", "resource.proto"),
    ("proto/pulumi/engine.proto", "engine.proto"),
    ("proto/pulumi/provider.proto", "provider.proto"),
    ("proto/pulumi/plugin.proto", "plugin.proto"),
    # Nested protos (same structure as Pulumi repo)
    ("proto/pulumi/alias.proto", "pulumi/alias.proto"),
    ("proto/pulumi/callback.proto", "pulumi/callback.proto"),
    ("proto/pulumi/source.proto", "pulumi/source.proto"),
    ("proto/pulumi/plugin.proto", "pulumi/plugin.proto"),
    ("proto/pulumi/provider.proto", "pulumi/provider.proto"),
    ("proto/pulumi/codegen/hcl.proto", "pulumi/codegen/hcl.proto"),
]

"""
    download_file(url::String, dest::String)

Download a file from URL to destination path.
Throws an error if download fails.
"""
function download_file(url::String, dest::String)
    Downloads.download(url, dest)
end

"""
    download_protos(ref::String, proto_dir::String)

Download all proto files from the specified git reference to proto_dir.
Uses atomic download pattern - downloads to temp dir first, then moves.
"""
function download_protos(ref::String, proto_dir::String)
    total = length(PROTO_FILES)

    # Create temp directory for atomic downloads
    tmpdir = mktempdir()

    try
        # Create subdirectories in temp dir
        mkpath(joinpath(tmpdir, "pulumi", "codegen"))

        # Download all files to temp directory
        for (i, (remote_path, local_path)) in enumerate(PROTO_FILES)
            url = "$GITHUB_BASE_URL/$ref/$remote_path"
            dest = joinpath(tmpdir, local_path)

            print("  [$i/$total] $local_path ... ")
            try
                download_file(url, dest)
                println("done")
            catch e
                println("FAILED")
                if isa(e, Downloads.RequestError) && e.response.status == 404
                    error("File not found: $remote_path (ref: $ref). Check if the version/commit exists.")
                else
                    rethrow(e)
                end
            end
        end

        # All downloads succeeded - move to final location atomically
        # Create target directories if needed
        mkpath(joinpath(proto_dir, "pulumi", "codegen"))

        for (_, local_path) in PROTO_FILES
            src = joinpath(tmpdir, local_path)
            dest = joinpath(proto_dir, local_path)
            mv(src, dest; force=true)
        end

        return true
    catch e
        # Clean up partial downloads handled by finally
        rethrow(e)
    finally
        rm(tmpdir; recursive=true, force=true)
    end
end

"""
    main(args::Vector{String}=ARGS)

Main entry point. Parses arguments and executes download.
"""
function main(args::Vector{String}=ARGS)
    # Get repository root (parent of gen/ directory)
    repo_root = dirname(@__DIR__)
    proto_dir = joinpath(repo_root, "proto")

    # Parse arguments
    ref = "master"
    generate = false

    for arg in args
        if arg == "--generate" || arg == "-g"
            generate = true
        elseif !startswith(arg, "-")
            ref = arg
        end
    end

    # Progress output with info
    println("=" ^ 60)
    println("Proto File Download")
    println("=" ^ 60)
    println("  Source:           github.com/pulumi/pulumi")
    println("  Git Reference:    $ref")
    println("  Output directory: $proto_dir")
    println("  Proto files:      $(length(PROTO_FILES))")
    println()

    # Download proto files
    println("Downloading proto files...")
    try
        download_protos(ref, proto_dir)
    catch e
        println()
        println("ERROR: Download failed!")
        println("  $(e)")
        println()
        println("Possible causes:")
        println("  - Network connection issues")
        println("  - Invalid version/commit reference: $ref")
        println("  - GitHub rate limiting (try again later)")
        println("=" ^ 60)
        return 1
    end

    println()
    println("Done! Downloaded $(length(PROTO_FILES)) proto files to: $proto_dir")
    println("=" ^ 60)

    # Optionally run code generation
    if generate
        println()
        println("Running code generation...")
        println()
        generate_script = joinpath(@__DIR__, "generate_protos.jl")
        include(generate_script)
    end

    return 0
end

# Run main when script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
