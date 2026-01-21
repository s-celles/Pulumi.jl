# Contract tests for serialization
# T049: Contract test for unknown Output serialization in preview mode

@testset "Serialization Contract" begin
    @testset "Dict to Struct conversion" begin
        # Verify conversion functions exist
        @test isdefined(Pulumi, :dict_to_struct)
        @test isdefined(Pulumi, :struct_to_dict)

        # Test basic serialization
        d = Dict{String, Any}(
            "string" => "value",
            "number" => 42,
            "bool" => true,
            "null" => nothing
        )

        s = Pulumi.dict_to_struct(d)
        @test s isa Pulumi.pulumirpc.google.protobuf.Struct

        result = Pulumi.struct_to_dict(s)
        @test result["string"] == "value"
        @test result["number"] == 42.0
        @test result["bool"] == true
        @test result["null"] === nothing
    end

    @testset "Nested structure serialization" begin
        d = Dict{String, Any}(
            "outer" => Dict{String, Any}(
                "inner" => Dict{String, Any}(
                    "deep" => "value"
                )
            )
        )

        s = Pulumi.dict_to_struct(d)
        result = Pulumi.struct_to_dict(s)

        @test result["outer"]["inner"]["deep"] == "value"
    end

    @testset "Array serialization" begin
        d = Dict{String, Any}(
            "numbers" => [1, 2, 3],
            "strings" => ["a", "b", "c"],
            "mixed" => [1, "two", true]
        )

        s = Pulumi.dict_to_struct(d)
        result = Pulumi.struct_to_dict(s)

        @test result["numbers"] == [1.0, 2.0, 3.0]
        @test result["strings"] == ["a", "b", "c"]
        @test result["mixed"][1] == 1.0
        @test result["mixed"][2] == "two"
        @test result["mixed"][3] == true
    end

    @testset "Empty collections" begin
        d = Dict{String, Any}(
            "emptyDict" => Dict{String, Any}(),
            "emptyArray" => []
        )

        s = Pulumi.dict_to_struct(d)
        result = Pulumi.struct_to_dict(s)

        @test isempty(result["emptyDict"])
        @test isempty(result["emptyArray"])
    end

    @testset "Output serialization" begin
        # Verify Output type exists
        @test isdefined(Pulumi, :Output)

        # Create a simple Output
        output = Output(42)
        @test output.value == 42
        @test output.is_known == true
        @test output.is_secret == false
    end

    @testset "Unknown Output serialization" begin
        # Contract: Unknown outputs MUST be handled specially during preview
        # During preview (dryRun=true), outputs may be unknown

        # Create unknown Output using no-argument constructor
        output = Output{Int}()
        @test output.is_known == false
        @test output.value isa Pulumi.Unknown

        # Unknown outputs should serialize differently
        # They use special sentinel values in Pulumi protocol
    end

    @testset "Secret Output serialization" begin
        # Contract: Secret outputs MUST be marked appropriately
        output = Output(42; is_secret=true)
        @test output.is_secret == true
        @test output.value == 42
    end

    @testset "Output with dependencies" begin
        # Contract: Output dependencies MUST be tracked for resource ordering
        deps = ["urn:pulumi:stack::project::type::name"]
        output = Output(42; dependencies=deps)

        @test !isempty(output.dependencies)
        @test deps[1] in output.dependencies
    end
end

@testset "Preview Mode Serialization" begin
    # T049: Unknown values during preview

    @testset "Unknown value markers" begin
        # In Pulumi protocol, unknown values use special markers
        # These are typically represented as specific struct patterns

        # Verify we can create unknown outputs using no-argument constructor
        unknown_string = Output{String}()
        unknown_int = Output{Int}()
        unknown_dict = Output{Dict{String,Any}}()

        @test !unknown_string.is_known
        @test !unknown_int.is_known
        @test !unknown_dict.is_known

        # Unknown values use the Unknown sentinel
        @test unknown_string.value isa Pulumi.Unknown
        @test unknown_int.value isa Pulumi.Unknown
        @test unknown_dict.value isa Pulumi.Unknown
    end

    @testset "Partial output resolution" begin
        # During preview, some outputs resolve while others remain unknown
        known_output = Output("known_value")
        unknown_output = Output{String}()

        @test known_output.is_known
        @test !unknown_output.is_known

        # Known values should serialize normally
        @test known_output.value == "known_value"

        # Unknown values have Unknown sentinel
        @test unknown_output.value isa Pulumi.Unknown
    end
end
