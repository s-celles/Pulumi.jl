using Documenter
using Pulumi

# `service_descriptor` is documented on Pulumi's runtime type but owned by
# gRPCServer, so the binding must be reachable from this module.
import gRPCServer

const REPO = "github.com/s-celles/Pulumi.jl.git"
const SITE = "https://s-celles.github.io/Pulumi.jl/"
const TAGLINE = "A community Julia SDK for Pulumi: define cloud infrastructure in Julia."

const PAGES = [
    "Home" => "index.md",
    "Getting Started" => [
        "Installation" => "getting-started/installation.md",
        "Quick Start" => "getting-started/quickstart.md",
    ],
    "Guides" => [
        "Resources" => "guides/resources.md",
        "Outputs" => "guides/outputs.md",
        "Configuration" => "guides/configuration.md",
        "Components" => "guides/components.md",
        "Stack Exports" => "guides/exports.md",
        "Language Host" => "guides/language-host.md",
    ],
    "API Reference" => "api.md",
    "Internals" => "internals.md",
    "Maintenance" => "maintenance.md",
]

"""
    flatten_pages(pages, section="") -> Vector{Tuple{String, String, String}}

Flatten the nested `pages` structure into `(section, title, path)` triples, in
the order they appear in the navigation.
"""
function flatten_pages(pages, section::String = "")
    entries = Tuple{String, String, String}[]
    for page in pages
        title, target = page
        if target isa AbstractString
            push!(entries, (section, title, target))
        else
            append!(entries, flatten_pages(target, title))
        end
    end
    return entries
end

"""
    page_url(path) -> String

Map a documentation source path to its published URL.
"""
function page_url(path::AbstractString)
    path == "index.md" && return SITE
    return SITE * replace(path, ".md" => "/")
end

"""
    write_llms_files(build_dir)

Write `llms.txt` and `llms-full.txt` next to the built documentation.

`llms.txt` is the navigational index described by <https://llmstxt.org>, and
`llms-full.txt` inlines the full Markdown of every page so a model can read the
documentation in a single fetch. Both are served from the documentation site,
never from the repository root.
"""
function write_llms_files(build_dir::AbstractString)
    entries = flatten_pages(PAGES)
    source_dir = joinpath(@__DIR__, "src")

    open(joinpath(build_dir, "llms.txt"), "w") do io
        println(io, "# Pulumi.jl")
        println(io)
        println(io, "> ", TAGLINE)
        println(io)
        println(io, "Pulumi.jl is an experimental, community-developed SDK. It is not an")
        println(io, "official product of Pulumi Corporation.")
        println(io)

        # Group by section, keeping the order in which each section first
        # appears in the navigation.
        headings = String[]
        grouped = Dict{String, Vector{Tuple{String, String}}}()
        for (section, title, path) in entries
            heading = isempty(section) ? "Docs" : section
            heading in headings || push!(headings, heading)
            push!(get!(grouped, heading, Tuple{String, String}[]), (title, path))
        end

        for heading in headings
            println(io, "## ", heading)
            println(io)
            for (title, path) in grouped[heading]
                println(io, "- [", title, "](", page_url(path), ")")
            end
            println(io)
        end
    end

    open(joinpath(build_dir, "llms-full.txt"), "w") do io
        println(io, "# Pulumi.jl")
        println(io)
        println(io, "> ", TAGLINE)
        println(io)
        println(io, "This file contains the full documentation in a single document.")

        for (_, title, path) in entries
            source = joinpath(source_dir, path)
            isfile(source) || continue
            println(io)
            println(io, "---")
            println(io)
            println(io, "# ", title)
            println(io)
            println(io, read(source, String))
        end
    end

    return nothing
end

makedocs(
    sitename = "Pulumi.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = SITE,
    ),
    modules = [Pulumi],
    pages = PAGES,
)

write_llms_files(joinpath(@__DIR__, "build"))

deploydocs(
    repo = REPO,
    devbranch = "main",
    push_preview = true,
)
