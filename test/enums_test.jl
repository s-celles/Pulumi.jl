@testset "LogSeverity" begin
    @test LogSeverity.DEBUG == "debug"
    @test LogSeverity.INFO == "info"
    @test LogSeverity.WARNING == "warning"
    @test LogSeverity.ERROR == "error"
    @test LogSeverity.T === String
end

@testset "ResourceState" begin
    @test ResourceState.PENDING isa ResourceState.T
    @test ResourceState.CREATING isa ResourceState.T
    @test ResourceState.CREATED isa ResourceState.T
    @test ResourceState.UPDATING isa ResourceState.T
    @test ResourceState.DELETING isa ResourceState.T
    @test ResourceState.DELETED isa ResourceState.T
    @test ResourceState.FAILED isa ResourceState.T
end
