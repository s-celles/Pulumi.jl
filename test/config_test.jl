@testset "Config" begin
    # Save original environment
    original_env = Dict{String, String}()
    env_keys = [
        "PULUMI_PROJECT", "PULUMI_STACK", "PULUMI_CONFIG",
        "PULUMI_CONFIG_SECRET_KEYS", "PULUMI_MONITOR", "PULUMI_ENGINE"
    ]
    for key in env_keys
        if haskey(ENV, key)
            original_env[key] = ENV[key]
        end
    end

    try
        # Set up test environment
        reset_context!()
        ENV["PULUMI_PROJECT"] = "test-project"
        ENV["PULUMI_STACK"] = "dev"
        ENV["PULUMI_MONITOR"] = ""
        ENV["PULUMI_ENGINE"] = ""
        ENV["PULUMI_CONFIG"] = """{
            "test-project:stringKey": "string-value",
            "test-project:intKey": "42",
            "test-project:boolKey": "true",
            "test-project:floatKey": "3.14",
            "test-project:secretKey": "secret-value",
            "test-project:jsonKey": "{\\"nested\\": \\"value\\"}"
        }"""
        ENV["PULUMI_CONFIG_SECRET_KEYS"] = """["test-project:secretKey"]"""

        @testset "Config creation" begin
            config = Config()
            @test config.namespace == "test-project"

            config_custom = Config("custom-namespace")
            @test config_custom.namespace == "custom-namespace"
        end

        @testset "Config get" begin
            config = Config()

            # Existing key
            value = get(config, "stringKey")
            @test value == "string-value"

            # Non-existing key
            missing_value = get(config, "nonExistent")
            @test missing_value === nothing

            # With default
            default_value = get(config, "nonExistent", "default")
            @test default_value == "default"
        end

        @testset "Config require" begin
            config = Config()

            # Existing key
            value = require(config, "stringKey")
            @test value == "string-value"

            # Missing key
            @test_throws ConfigMissingError require(config, "nonExistent")
        end

        @testset "Config is_secret" begin
            config = Config()

            @test is_secret(config, "secretKey") == true
            @test is_secret(config, "stringKey") == false
        end

        @testset "Config get_secret" begin
            config = Config()

            # Existing secret
            secret = get_secret(config, "secretKey")
            @test secret !== nothing
            @test secret isa Output
            @test secret.value == "secret-value"
            @test secret.is_secret == true

            # Non-existing key
            missing_secret = get_secret(config, "nonExistent")
            @test missing_secret === nothing
        end

        @testset "Config require_secret" begin
            config = Config()

            # Existing key (treated as secret)
            secret = require_secret(config, "stringKey")
            @test secret isa Output
            @test secret.is_secret == true

            # Missing key
            @test_throws ConfigMissingError require_secret(config, "nonExistent")
        end

        @testset "Config type conversions" begin
            config = Config()

            # Integer
            int_val = get_int(config, "intKey")
            @test int_val == 42
            @test int_val isa Int

            # Boolean
            bool_val = get_bool(config, "boolKey")
            @test bool_val == true
            @test bool_val isa Bool

            # Float
            float_val = get_float(config, "floatKey")
            @test float_val ≈ 3.14
            @test float_val isa Float64

            # Object
            obj_val = get_object(config, "jsonKey")
            @test obj_val !== nothing
            @test obj_val isa Dict
            @test obj_val["nested"] == "value"

            # Missing values return nothing
            @test get_int(config, "nonExistent") === nothing
            @test get_bool(config, "nonExistent") === nothing
            @test get_float(config, "nonExistent") === nothing
            @test get_object(config, "nonExistent") === nothing
        end

        @testset "Config show" begin
            config = Config()
            io = IOBuffer()
            show(io, config)
            output = String(take!(io))
            @test contains(output, "Config")
            @test contains(output, "test-project")
        end

        @testset "Config bracket syntax" begin
            config = Config()

            # Existing key with bracket syntax
            value = config["stringKey"]
            @test value == "string-value"

            # Missing key throws ConfigMissingError
            @test_throws ConfigMissingError config["nonExistent"]
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
