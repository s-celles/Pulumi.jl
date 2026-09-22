# Tests for the wire representation of resource options.
#
# `_build_register_resource_request` is the single point where a Julia
# `ResourceOptions` becomes a `RegisterResourceRequest`, so these tests assert
# that each option actually reaches the protobuf message the engine receives.

const Alias = Pulumi.pulumirpc.Alias
const CustomTimeouts = Pulumi.pulumirpc.var"RegisterResourceRequest.CustomTimeouts"

"""
    base_request(; kwargs...) -> Dict{String, Any}

A minimal valid request dict, with `kwargs` merged in.
"""
function base_request(; kwargs...)
    request = Dict{String, Any}(
        "type" => "aws:s3/bucket:Bucket",
        "name" => "my-bucket",
        "object" => Dict{String, Any}(),
    )
    for (key, value) in kwargs
        request[string(key)] = value
    end
    return request
end

@testset "Resource option wire format" begin
    @testset "Identity and hierarchy" begin
        parent_urn = "urn:pulumi:dev::proj::my:mod:Component::parent"
        provider_urn = "urn:pulumi:dev::proj::pulumi:providers:aws::default"

        message = Pulumi._build_register_resource_request(base_request(
            parent = parent_urn,
            provider = provider_urn,
            custom = true,
        ))

        @test message.var"#type" == "aws:s3/bucket:Bucket"
        @test message.name == "my-bucket"
        @test message.parent == parent_urn
        @test message.provider == provider_urn
        @test message.custom
    end

    @testset "protect" begin
        @test Pulumi._build_register_resource_request(base_request(protect = true)).protect
        @test !Pulumi._build_register_resource_request(base_request()).protect
    end

    @testset "dependencies" begin
        urns = ["urn:pulumi:dev::proj::aws:s3/bucket:Bucket::a",
                "urn:pulumi:dev::proj::aws:s3/bucket:Bucket::b"]
        message = Pulumi._build_register_resource_request(base_request(dependencies = urns))
        @test message.dependencies == urns
    end

    @testset "propertyDependencies" begin
        message = Pulumi._build_register_resource_request(base_request(
            propertyDependencies = Dict("bucket" => ["urn:a", "urn:b"]),
        ))
        @test haskey(message.propertyDependencies, "bucket")
        @test message.propertyDependencies["bucket"].urns == ["urn:a", "urn:b"]
    end

    @testset "ignoreChanges and replaceOnChanges" begin
        message = Pulumi._build_register_resource_request(base_request(
            ignoreChanges = ["tags", "acl"],
            replaceOnChanges = ["bucket"],
        ))
        @test message.ignoreChanges == ["tags", "acl"]
        @test message.replaceOnChanges == ["bucket"]
    end

    @testset "retainOnDelete" begin
        @test Pulumi._build_register_resource_request(base_request(retainOnDelete = true)).retainOnDelete
        @test !Pulumi._build_register_resource_request(base_request()).retainOnDelete
    end

    @testset "version and importId" begin
        message = Pulumi._build_register_resource_request(base_request(
            version = "6.0.0",
            importId = "existing-bucket",
        ))
        @test message.version == "6.0.0"
        @test message.importId == "existing-bucket"
    end

    @testset "deleteBeforeReplace" begin
        # The engine ignores `deleteBeforeReplace` unless the companion
        # `deleteBeforeReplaceDefined` flag says the user set it explicitly.
        message = Pulumi._build_register_resource_request(base_request(deleteBeforeReplace = true))
        @test message.deleteBeforeReplace
        @test message.deleteBeforeReplaceDefined

        default = Pulumi._build_register_resource_request(base_request())
        @test !default.deleteBeforeReplace
        @test !default.deleteBeforeReplaceDefined
    end

    @testset "aliases" begin
        @testset "URN strings become Alias messages" begin
            urns = ["urn:pulumi:dev::proj::aws:s3/bucket:Bucket::old",
                    "urn:pulumi:dev::proj::aws:s3/bucket:Bucket::older"]
            message = Pulumi._build_register_resource_request(base_request(aliases = urns))

            @test length(message.aliases) == 2
            @test Base.all(a -> a isa Alias, message.aliases)  # `all` is ambiguous: Pulumi exports its own
            @test [a.alias.name for a in message.aliases] == [:urn, :urn]
            @test [a.alias[] for a in message.aliases] == urns
        end

        @testset "Alias messages are passed through" begin
            spec = Pulumi.pulumirpc.var"Alias.Spec"("old-name", "", "", "", nothing)
            alias = Alias(Pulumi.PB.OneOf(:spec, spec))
            message = Pulumi._build_register_resource_request(base_request(aliases = [alias]))

            @test length(message.aliases) == 1
            @test message.aliases[1].alias.name == :spec
            @test message.aliases[1].alias[].name == "old-name"
        end

        @testset "No aliases" begin
            message = Pulumi._build_register_resource_request(base_request())
            @test isempty(message.aliases)
            # The deprecated string field must stay empty now that `aliases` is
            # populated.
            @test isempty(message.aliasURNs)
        end
    end

    @testset "customTimeouts" begin
        @testset "All three timeouts" begin
            message = Pulumi._build_register_resource_request(base_request(
                customTimeouts = Dict("create" => "10m", "update" => "5m", "delete" => "1h"),
            ))
            @test message.customTimeouts isa CustomTimeouts
            @test message.customTimeouts.create == "10m"
            @test message.customTimeouts.update == "5m"
            @test message.customTimeouts.delete == "1h"
        end

        @testset "Partial timeouts leave the rest empty" begin
            message = Pulumi._build_register_resource_request(base_request(
                customTimeouts = Dict("create" => "30m"),
            ))
            @test message.customTimeouts.create == "30m"
            @test message.customTimeouts.update == ""
            @test message.customTimeouts.delete == ""
        end

        @testset "Absent timeouts stay unset" begin
            @test Pulumi._build_register_resource_request(base_request()).customTimeouts === nothing
            @test Pulumi._build_register_resource_request(
                base_request(customTimeouts = nothing)
            ).customTimeouts === nothing
        end
    end
end

@testset "ResourceOptions plumbing" begin
    @testset "custom_timeouts reaches ResourceOptions" begin
        options = Pulumi.ResourceOptions(
            custom_timeouts = Dict("create" => "10m"),
        )
        @test options.custom_timeouts == Dict("create" => "10m")
    end

    @testset "register_resource accepts custom_timeouts" begin
        # The keyword must exist even though calling it needs a live monitor.
        method = only(methods(register_resource))
        @test :custom_timeouts in Base.kwarg_decl(method)
    end
end
