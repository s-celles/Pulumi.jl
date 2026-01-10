@testset "Stack Exports" begin
    @testset "export_value" begin
        clear_exports!()

        export_value("simpleValue", 42)
        export_value("stringValue", "hello")
        export_value("outputValue", Output("computed"))

        exports = get_exports()
        @test exports["simpleValue"] == 42
        @test exports["stringValue"] == "hello"
        @test exports["outputValue"] isa Output
    end

    @testset "export_secret" begin
        clear_exports!()

        # Plain value becomes secret Output
        export_secret("password", "secret123")
        exports = get_exports()
        @test exports["password"] isa Output
        @test exports["password"].is_secret == true
        @test exports["password"].value == "secret123"

        # Non-secret Output becomes secret
        clear_exports!()
        export_secret("token", Output("token-value"))
        exports = get_exports()
        @test exports["token"].is_secret == true

        # Already secret Output stays secret
        clear_exports!()
        export_secret("apiKey", Output("key"; is_secret=true))
        exports = get_exports()
        @test exports["apiKey"].is_secret == true
    end

    @testset "get_exports thread safety" begin
        clear_exports!()

        # Concurrent exports
        tasks = [
            Threads.@spawn export_value("key$i", i)
            for i in 1:10
        ]
        foreach(wait, tasks)

        exports = get_exports()
        @test length(exports) == 10
    end

    @testset "clear_exports" begin
        export_value("temp", "value")
        @test !isempty(get_exports())

        clear_exports!()
        @test isempty(get_exports())
    end
end
