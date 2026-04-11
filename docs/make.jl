using Documenter
using Pulumi

makedocs(
    sitename = "Pulumi.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://s-celles.github.io/Pulumi.jl/",
    ),
    modules = [Pulumi],
    pages = [
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
        ],
        "API Reference" => "api.md",
    ],
    warnonly = [:missing_docs],
)

deploydocs(
    repo = "github.com/s-celles/Pulumi.jl.git",
    devbranch = "main",
    push_preview = true,
)
