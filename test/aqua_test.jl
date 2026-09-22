# Aqua.jl quality checks.
#
# All checks are enabled: the package must stay free of method ambiguities,
# stale dependencies, type piracy and missing compat bounds.

using Aqua

@testset "Aqua.jl" begin
    Aqua.test_all(Pulumi)
end
