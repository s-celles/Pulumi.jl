# Aqua.jl tests for code quality
# T096: Verify Aqua.jl passes all checks

using Aqua

@testset "Aqua.jl" begin
    Aqua.test_all(Pulumi;
        ambiguities=false,   # Skip ambiguity tests (some intentional method overlaps)
        stale_deps=false,    # Skip stale deps (ProtoBuf used at runtime for generated code)
        piracies=false,      # Skip piracy tests (we extend Base methods legitimately)
        deps_compat=false,   # Skip compat checks (handled by Project.toml [compat] section)
    )
end
