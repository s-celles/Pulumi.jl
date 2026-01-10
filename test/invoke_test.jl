@testset "Invoke" begin
    # Note: These are basic tests; full invoke testing requires a mock monitor

    @testset "invoke returns Output" begin
        # Save original context
        original_env = Dict{String, String}()
        env_keys = ["PULUMI_PROJECT", "PULUMI_STACK", "PULUMI_MONITOR", "PULUMI_ENGINE", "PULUMI_CONFIG", "PULUMI_CONFIG_SECRET_KEYS"]
        for key in env_keys
            if haskey(ENV, key)
                original_env[key] = ENV[key]
            end
        end

        try
            reset_context!()
            ENV["PULUMI_PROJECT"] = "test"
            ENV["PULUMI_STACK"] = "dev"
            ENV["PULUMI_MONITOR"] = "localhost:12345"
            ENV["PULUMI_ENGINE"] = ""
            ENV["PULUMI_CONFIG"] = "{}"
            ENV["PULUMI_CONFIG_SECRET_KEYS"] = "[]"

            # This will use the mock implementation (use Pulumi.invoke to avoid conflict with Base.invoke)
            result = Pulumi.invoke("test:provider:function", Dict{String, Any}("arg1" => "value"))

            @test result isa Output
        finally
            for key in env_keys
                if haskey(original_env, key)
                    ENV[key] = original_env[key]
                else
                    delete!(ENV, key)
                end
            end
            reset_context!()
        end
    end
end
