# Integration tests for component resources.
#
# These run a real gRPC round trip against the fake engine, so they assert on
# what the Pulumi engine actually receives, not just on the Julia side.

@testitem "Component Resources" setup=[TestSupport] begin
    @testset "Component with children" begin
        TestSupport.with_fake_engine() do engine
            child = Ref{Any}(nothing)

            comp = component("my:mod:Bucket", "assets") do _
                child[] = register_resource("aws:s3:Bucket", "assets-bucket",
                    Dict{String, Any}("acl" => "private"))
                return (bucket = child[],)
            end

            @test comp isa ComponentResource
            @test comp.state == Pulumi.ResourceState.CREATED
            @test get_urn(comp) == "urn:pulumi:dev::test-project::my:mod:Bucket::assets"

            # The child returned by the body is recorded on the component.
            @test length(comp.children) == 1
            @test comp.children[1] === child[]

            # The engine saw the component first, then its child.
            @test length(engine.registrations) == 2
            component_request, child_request = engine.registrations

            @test component_request.var"#type" == "my:mod:Bucket"
            @test component_request.name == "assets"
            # A component is not provider-managed.
            @test !component_request.custom

            @test child_request.var"#type" == "aws:s3:Bucket"
            @test child_request.custom
        end
    end

    @testset "Nested components" begin
        TestSupport.with_fake_engine() do engine
            outer = component("my:mod:Outer", "outer") do parent
                inner = component("my:mod:Inner", "inner"; parent = parent) do _
                    return register_resource("aws:s3:Bucket", "inner-bucket",
                        Dict{String, Any}())
                end
                return (inner = inner,)
            end

            @test length(outer.children) == 1
            inner = outer.children[1]
            @test inner isa ComponentResource
            @test length(inner.children) == 1

            # Registration order: outer, inner, then the innermost resource.
            @test length(engine.registrations) == 3
            outer_request, inner_request, leaf_request = engine.registrations

            @test outer_request.name == "outer"
            @test isempty(outer_request.parent)

            # The nested component is parented to the outer one.
            @test inner_request.name == "inner"
            @test inner_request.parent == get_urn(outer)

            @test leaf_request.name == "inner-bucket"
        end
    end

    @testset "register_outputs publishes the component's outputs" begin
        TestSupport.with_fake_engine() do engine
            comp = component("my:mod:Bucket", "assets") do _
                return register_resource("aws:s3:Bucket", "assets-bucket", Dict{String, Any}())
            end

            register_outputs(comp, Dict{String, Any}(
                "bucketName" => "assets-bucket",
                "region" => "eu-west-1",
            ))

            @test length(engine.outputs) == 1
            request = engine.outputs[1]
            @test request.urn == get_urn(comp)

            published = Pulumi.struct_to_dict(request.outputs)
            @test published["bucketName"] == "assets-bucket"
            @test published["region"] == "eu-west-1"
        end
    end

    @testset "A failing body does not leave the component registered as created" begin
        TestSupport.with_fake_engine() do engine
            @test_throws ErrorException component("my:mod:Broken", "broken") do _
                error("child construction failed")
            end

            # The component itself was registered before the body ran.
            @test length(engine.registrations) == 1
            @test engine.registrations[1].name == "broken"
            # ... but nothing was published for it.
            @test isempty(engine.outputs)
        end
    end
end
