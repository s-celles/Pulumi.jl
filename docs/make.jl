using Documenter
using Pulumi

makedocs(
    sitename = "Pulumi.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://pulumi.github.io/pulumi-julia/",
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
    repo = "github.com/pulumi/pulumi-julia.git",
    devbranch = "main",
    push_preview = true,
)
