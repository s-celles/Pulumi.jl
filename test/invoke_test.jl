@testitem "Invoke" setup=[TestSupport] begin
    # Note: These are basic tests; full invoke testing requires a mock monitor

    @testset "invoke function exists" begin
        @test isdefined(Pulumi, :invoke)
        @test hasmethod(Pulumi.invoke, Tuple{String, Dict{String, Any}})
    end

    @testset "invoke reaches the monitor and returns an Output" begin
        TestSupport.with_fake_engine() do engine
            engine.invoke_results["test:index:getThing"] =
                Dict{String, Any}("name" => "thing", "size" => 7)

            result = Pulumi.invoke("test:index:getThing", Dict{String, Any}("id" => "abc"))

            @test result isa Output
            @test Pulumi.is_known(result)
            value = Pulumi.get_value(result)
            @test value["name"] == "thing"
            @test value["size"] == 7

            # The arguments really travelled to the monitor.
            @test length(engine.invokes) == 1
            @test engine.invokes[1].tok == "test:index:getThing"
            @test Pulumi.struct_to_dict(engine.invokes[1].args)["id"] == "abc"
        end
    end

    @testset "invoke without a canned result echoes its arguments" begin
        TestSupport.with_fake_engine() do _
            result = Pulumi.invoke("test:index:echo", Dict{String, Any}("hello" => "world"))
            @test Pulumi.get_value(result)["hello"] == "world"
        end
    end
end
