# Tests for the Pulumi special-value envelopes.
#
# Pulumi marks special values with a single reserved key whose value says which
# kind of special value it is. Getting the marker wrong makes the engine reject
# the whole property map with "unrecognized signature", which takes the
# deployment down, so the exact constants matter.

@testitem "Secret envelope" begin
    @testset "Signature constants match the Pulumi protocol" begin
        # The reserved key every special value uses.
        @test Pulumi.SIG_KEY == "4dabf18193072939515e22adb298388d"
        # The values that say which kind of special value it is.
        @test Pulumi.SECRET_SIG == "1b47061264138c4ac30d75fd1eb44270"
        @test Pulumi.RESOURCE_SIG == "5cf8f73096256a8f31e491e813e4eb8e"
        @test Pulumi.OUTPUT_SIG == "d0e6a833031e9bbcd3f4e8bde6ca49a4"
    end

    @testset "A secret Output serializes to the envelope the engine accepts" begin
        envelope = Pulumi.serialize_output(Output("hunter2"; is_secret = true))

        @test envelope isa Dict
        @test envelope[Pulumi.SIG_KEY] == Pulumi.SECRET_SIG
        @test envelope["value"] == "hunter2"
    end

    @testset "An unknown secret carries no value" begin
        envelope = Pulumi.serialize_output(Output{String}(is_secret = true))

        @test envelope[Pulumi.SIG_KEY] == Pulumi.SECRET_SIG
        @test envelope["value"] === nothing
    end

    @testset "A plain Output is not wrapped" begin
        @test Pulumi.serialize_output(Output("public")) == "public"
    end

    @testset "Round trip through the wire format" begin
        envelope = Pulumi.serialize_output(Output("hunter2"; is_secret = true))
        decoded = Pulumi.deserialize_struct(envelope)

        @test Pulumi.is_secret_value(decoded)
        @test Pulumi.unwrap_secret(decoded) == "hunter2"
    end

    @testset "Other special values are not mistaken for secrets" begin
        # A resource reference uses the same key with a different signature.
        reference = Dict{String, Any}(
            Pulumi.SIG_KEY => Pulumi.RESOURCE_SIG,
            "urn" => "urn:pulumi:dev::proj::aws:s3/bucket:Bucket::b",
        )
        @test !Pulumi.is_secret_value(reference)
        @test Pulumi.unwrap_secret(reference) === reference
    end

    @testset "An ordinary dict is untouched" begin
        plain = Dict{String, Any}("a" => 1, "value" => 2)
        @test !Pulumi.is_secret_value(plain)
        @test Pulumi.unwrap_secret(plain) === plain
    end
end
