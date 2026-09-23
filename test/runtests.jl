# The suite is written as TestItemRunner test items: every `@testitem` in this
# directory runs in its own module, so they can be run individually from an
# editor as well as all together here.
#
# Shared setup lives in `test_support.jl` as the `TestSupport` test module.
#
# Pass a pattern to run only the matching items, by name or by file:
#
#     julia --project=. -e 'using Pkg; Pkg.test(test_args=["Secret envelope"])'
#     just test-item "Secret envelope"

using TestItemRunner

if isempty(ARGS)
    @run_package_tests
else
    let pattern = ARGS[1]
        @run_package_tests filter = ti -> occursin(pattern, ti.name) ||
                                          occursin(pattern, ti.filename)
    end
end
