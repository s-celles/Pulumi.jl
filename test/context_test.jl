@testset "Context" begin
    # Save original environment
    original_env = Dict{String, String}()
    env_keys = [
        "PULUMI_PROJECT", "PULUMI_STACK", "PULUMI_ORGANIZATION",
        "PULUMI_DRY_RUN", "PULUMI_PARALLEL", "PULUMI_MONITOR",
        "PULUMI_ENGINE", "PULUMI_CONFIG", "PULUMI_CONFIG_SECRET_KEYS"
    ]
    for key in env_keys
        if haskey(ENV, key)
            original_env[key] = ENV[key]
        end
    end

    try
        @testset "Context from environment" begin
            # Reset context before test
            reset_context!()

            # Set up test environment
            ENV["PULUMI_PROJECT"] = "test-project"
            ENV["PULUMI_STACK"] = "dev"
            ENV["PULUMI_ORGANIZATION"] = "test-org"
            ENV["PULUMI_DRY_RUN"] = "true"
            ENV["PULUMI_PARALLEL"] = "8"
            ENV["PULUMI_MONITOR"] = ""
            ENV["PULUMI_ENGINE"] = ""
            ENV["PULUMI_CONFIG"] = """{"test-project:key1": "value1", "test-project:key2": "value2"}"""
            ENV["PULUMI_CONFIG_SECRET_KEYS"] = """["test-project:secret1"]"""

            ctx = get_context()
            @test ctx.project == "test-project"
            @test ctx.stack == "dev"
            @test ctx.organization == "test-org"
            @test ctx.is_dry_run == true
            @test ctx.parallel == 8
            @test haskey(ctx.config, "test-project:key1")
            @test ctx.config["test-project:key1"] == "value1"
            @test "test-project:secret1" in ctx.config_secret_keys
        end

        @testset "Context accessors" begin
            reset_context!()
            ENV["PULUMI_PROJECT"] = "accessor-project"
            ENV["PULUMI_STACK"] = "staging"
            ENV["PULUMI_ORGANIZATION"] = "my-org"
            ENV["PULUMI_DRY_RUN"] = "false"
            ENV["PULUMI_CONFIG"] = "{}"
            ENV["PULUMI_CONFIG_SECRET_KEYS"] = "[]"

            @test get_project() == "accessor-project"
            @test get_stack() == "staging"
            @test get_organization() == "my-org"
            @test is_dry_run() == false
        end

        @testset "Context singleton" begin
            reset_context!()
            ENV["PULUMI_PROJECT"] = "singleton-project"
            ENV["PULUMI_STACK"] = "test"
            ENV["PULUMI_CONFIG"] = "{}"
            ENV["PULUMI_CONFIG_SECRET_KEYS"] = "[]"

            ctx1 = get_context()
            ctx2 = get_context()
            @test ctx1 === ctx2  # Same instance
        end

        @testset "Context reset" begin
            reset_context!()
            ENV["PULUMI_PROJECT"] = "reset-project-1"
            ENV["PULUMI_STACK"] = "dev"
            ENV["PULUMI_CONFIG"] = "{}"
            ENV["PULUMI_CONFIG_SECRET_KEYS"] = "[]"

            ctx1 = get_context()
            @test ctx1.project == "reset-project-1"

            reset_context!()
            ENV["PULUMI_PROJECT"] = "reset-project-2"
            ctx2 = get_context()
            @test ctx2.project == "reset-project-2"
            @test ctx1 !== ctx2
        end

        @testset "Context show" begin
            reset_context!()
            ENV["PULUMI_PROJECT"] = "show-project"
            ENV["PULUMI_STACK"] = "dev"
            ENV["PULUMI_CONFIG"] = "{}"
            ENV["PULUMI_CONFIG_SECRET_KEYS"] = "[]"

            ctx = get_context()
            io = IOBuffer()
            show(io, ctx)
            output = String(take!(io))
            @test contains(output, "show-project")
            @test contains(output, "dev")
        end

    finally
        # Restore original environment
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
