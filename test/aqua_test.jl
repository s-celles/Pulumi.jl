# Aqua.jl quality checks.
#
# All checks are enabled: the package must stay free of method ambiguities,
# stale dependencies, type piracy and missing compat bounds.

@testitem "Aqua.jl" begin
    using Aqua
    Aqua.test_all(Pulumi)
end
