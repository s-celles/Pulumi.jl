@testset "Unknown type" begin
    u = Unknown()
    @test u isa Unknown

    io = IOBuffer()
    show(io, u)
    @test String(take!(io)) == "<unknown>"
end
