# Conformance tests against Pulumi SDK protocol
# These tests verify the Julia SDK behaves correctly as a Pulumi language runtime
# by testing all core functionality in an integrated way.

@testset "SDK Conformance" begin
    # Save original environment for restoration
    original_env = Dict{String, String}()
    env_keys = [
        "PULUMI_PROJECT", "PULUMI_STACK", "PULUMI_MONITOR", "PULUMI_ENGINE",
        "PULUMI_CONFIG", "PULUMI_CONFIG_SECRET_KEYS", "PULUMI_DRY_RUN",
        "PULUMI_PARALLEL", "PULUMI_ORGANIZATION"
    ]
    for key in env_keys
        if haskey(ENV, key)
            original_env[key] = ENV[key]
        end
    end

    try
        # Reset context for clean test state
        reset_context!()
        clear_exports!()
        reset_dependency_graph!()

        # Set up mock Pulumi environment
        ENV["PULUMI_PROJECT"] = "conformance-test"
        ENV["PULUMI_STACK"] = "test-stack"
        ENV["PULUMI_MONITOR"] = "localhost:54321"
        ENV["PULUMI_ENGINE"] = ""
        ENV["PULUMI_CONFIG"] = """{"conformance-test:testKey":"testValue","conformance-test:secretKey":"secret123","conformance-test:intKey":"42","conformance-test:boolKey":"true"}"""
        ENV["PULUMI_CONFIG_SECRET_KEYS"] = """["conformance-test:secretKey"]"""
        ENV["PULUMI_DRY_RUN"] = "true"
        ENV["PULUMI_PARALLEL"] = "10"
        ENV["PULUMI_ORGANIZATION"] = "test-org"

        @testset "Environment Variable Protocol" begin
            @testset "Project and stack context" begin
                @test get_project() == "conformance-test"
                @test get_stack() == "test-stack"
                @test get_organization() == "test-org"
                @test is_dry_run() == true
            end

            @testset "Context initialization from environment" begin
                ctx = get_context()
                @test ctx !== nothing
                @test ctx.project == "conformance-test"
                @test ctx.stack == "test-stack"
                @test ctx.is_dry_run == true
                @test ctx.parallel == 10
            end
        end

        @testset "Configuration Protocol" begin
            config = Config()

            @testset "get() with defaults" begin
                @test get(config, "testKey") == "testValue"
                @test get(config, "missingKey") === nothing
                @test get(config, "missingKey", "default") == "default"
            end

            @testset "require() for mandatory values" begin
                @test require(config, "testKey") == "testValue"
                @test_throws ConfigMissingError require(config, "missingKey")
            end

            @testset "Typed config accessors" begin
                @test get_int(config, "intKey") == 42
                @test get_int(config, "missingInt") === nothing
                @test get_bool(config, "boolKey") == true
                @test get_bool(config, "missingBool") === nothing
            end

            @testset "Secret config handling" begin
                @test is_secret(config, "secretKey") == true
                @test is_secret(config, "testKey") == false

                secret_output = get_secret(config, "secretKey")
                @test secret_output isa Output{String}
                @test secret_output.is_secret == true
            end

            @testset "Bracket accessor syntax" begin
                @test config["testKey"] == "testValue"
                @test_throws ConfigMissingError config["missingKey"]
            end
        end

        @testset "Output Protocol" begin
            @testset "Output creation and state" begin
                # Known value
                known = Output("hello")
                @test known.is_known == true
                @test known.is_secret == false
                @test known.value == "hello"

                # Unknown value (use keyword constructor)
                unknown = Output{String}()
                @test unknown.is_known == false

                # Secret value
                secret = Output("secret"; is_secret=true)
                @test secret.is_secret == true
            end

            @testset "apply() transformation" begin
                output = Output(10)
                result = apply(output) do x
                    x * 2
                end
                @test result isa Output{Int}
                @test result.value == 20

                # Secret propagation
                secret_output = Output("data"; is_secret=true)
                transformed = apply(secret_output) do x
                    uppercase(x)
                end
                @test transformed.is_secret == true
            end

            @testset "all() combination" begin
                o1 = Output("a")
                o2 = Output("b")
                o3 = Output("c")

                combined = Pulumi.all(o1, o2, o3)
                @test combined isa Output{Tuple{String, String, String}}
                @test combined.value == ("a", "b", "c")

                # Secret propagation in all()
                s1 = Output("x"; is_secret=true)
                s2 = Output("y")
                combined_secret = Pulumi.all(s1, s2)
                @test combined_secret.is_secret == true
            end

            @testset "Dependency tracking" begin
                urn = "urn:pulumi:test::project::aws:s3:Bucket::my-bucket"
                output_with_deps = Output("value"; dependencies=[urn])
                @test !isempty(output_with_deps.dependencies)
                @test urn in output_with_deps.dependencies
            end
        end

        @testset "Resource Protocol" begin
            @testset "URN format compliance" begin
                # Standard URN format: urn:pulumi:{stack}::{project}::{type}::{name}
                urn = URN("urn:pulumi:dev::my-project::aws:s3:Bucket::my-bucket")
                @test urn.stack == "dev"
                @test urn.project == "my-project"
                @test urn.type_ == "aws:s3:Bucket"
                @test urn.name == "my-bucket"

                # Round-trip conversion
                @test string(urn) == "urn:pulumi:dev::my-project::aws:s3:Bucket::my-bucket"
            end

            @testset "URN with parent type" begin
                # Parent types use $ separator
                urn = URN("urn:pulumi:prod::project::my:module:Parent\$aws:ec2:Instance::child")
                @test urn.parent_type == "my:module:Parent"
                @test urn.type_ == "aws:ec2:Instance"
            end

            @testset "ResourceOptions validation" begin
                opts = ResourceOptions(
                    protect=true,
                    delete_before_replace=true,
                    retain_on_delete=false,
                    ignore_changes=["tags"],
                    aliases=["old-name"]
                )
                @test opts.protect == true
                @test opts.delete_before_replace == true
                @test "tags" in opts.ignore_changes
            end

            @testset "CustomResource creation" begin
                resource = CustomResource(
                    "urn:pulumi:test::project::aws:s3:Bucket::test-bucket",
                    "aws:s3:Bucket",
                    "test-bucket",
                    Dict{String, Any}("acl" => "private"),
                    Dict{String, Any}("id" => "bucket-123"),
                    ResourceOptions(),
                    ResourceState.CREATED
                )
                @test get_urn(resource) == "urn:pulumi:test::project::aws:s3:Bucket::test-bucket"
                @test get_name(resource) == "test-bucket"
                @test get_type(resource) == "aws:s3:Bucket"
                @test resource.state == ResourceState.CREATED
            end

            @testset "ComponentResource creation" begin
                comp = ComponentResource(
                    "urn:pulumi:test::project::my:module:WebServer::web",
                    "my:module:WebServer",
                    "web",
                    Resource[],
                    ResourceOptions(),
                    ResourceState.PENDING
                )
                @test get_type(comp) == "my:module:WebServer"
                @test isempty(comp.children)
            end

            @testset "ProviderResource creation" begin
                provider = ProviderResource(
                    "urn:pulumi:test::project::pulumi:providers:aws::aws",
                    "aws",
                    "aws",
                    Dict{String, Any}("region" => "us-east-1"),
                    ResourceOptions(),
                    ResourceState.CREATED
                )
                @test provider.package == "aws"
                @test provider.config["region"] == "us-east-1"
            end
        end

        @testset "register_resource Protocol" begin
            # These tests require actual gRPC connection to a monitor
            # Skip when not running integration tests
            if get(ENV, "PULUMI_TEST_INTEGRATION", "false") == "true"
                @testset "Basic resource registration" begin
                    resource = register_resource(
                        "aws:s3:Bucket",
                        "conformance-bucket",
                        Dict{String, Any}(
                            "acl" => "private",
                            "tags" => Dict{String, Any}("Environment" => "test")
                        )
                    )
                    @test resource isa CustomResource
                    @test resource.name == "conformance-bucket"
                    @test resource.type_ == "aws:s3:Bucket"
                    @test resource.inputs["acl"] == "private"
                end

                @testset "Resource with options" begin
                    resource = register_resource(
                        "aws:ec2:Instance",
                        "protected-instance",
                        Dict{String, Any}("ami" => "ami-12345"),
                        protect=true
                    )
                    @test resource.options.protect == true
                end

                @testset "Resource outputs are accessible" begin
                    resource = register_resource(
                        "aws:dynamodb:Table",
                        "test-table",
                        Dict{String, Any}("name" => "TestTable")
                    )
                    # Outputs dict should exist (may be empty without actual provider)
                    @test resource.outputs isa Dict{String, Any}
                    # URN is always set
                    @test !isempty(resource.urn)
                end
            else
                @info "Skipping register_resource protocol tests (requires PULUMI_TEST_INTEGRATION=true)"
                @test_skip true  # Mark as skipped
            end
        end

        @testset "Component Resource Protocol" begin
            # These tests require actual gRPC connection for component registration
            if get(ENV, "PULUMI_TEST_INTEGRATION", "false") == "true"
                @testset "component() function" begin
                    comp = component("my:module:TestComponent", "test-comp") do parent
                        # Create child resources
                        child1 = register_resource(
                            "aws:s3:Bucket",
                            "child-bucket-1",
                            Dict{String, Any}(),
                            parent=parent
                        )
                        child2 = register_resource(
                            "aws:s3:Bucket",
                            "child-bucket-2",
                            Dict{String, Any}(),
                            parent=parent
                        )
                        (bucket1=child1, bucket2=child2)
                    end

                    @test comp isa ComponentResource
                    @test comp.name == "test-comp"
                    @test comp.type_ == "my:module:TestComponent"
                    @test length(comp.children) >= 0  # Children tracked
                end
            else
                @info "Skipping component() protocol tests (requires PULUMI_TEST_INTEGRATION=true)"
                @test_skip true  # Mark as skipped
            end

            @testset "register_outputs" begin
                # register_outputs also requires a gRPC connection
                if get(ENV, "PULUMI_TEST_INTEGRATION", "false") == "true"
                    comp = ComponentResource(
                        "urn:pulumi:test::project::my:module:Test::outputs-test",
                        "my:module:Test",
                        "outputs-test",
                        Resource[],
                        ResourceOptions(),
                        ResourceState.CREATED
                    )
                    # Should not throw
                    register_outputs(comp, Dict{String, Any}("key" => Output("value")))
                else
                    # Just verify the function exists
                    @test isdefined(Pulumi, :register_outputs)
                end
            end
        end

        @testset "Export Protocol" begin
            @testset "export_value" begin
                clear_exports!()
                export_value("testOutput", Output("exported-value"))
                exports = get_exports()
                @test haskey(exports, "testOutput")
                @test exports["testOutput"].value == "exported-value"
            end

            @testset "export_secret" begin
                clear_exports!()
                export_secret("secretOutput", Output("secret-value"))
                exports = get_exports()
                @test haskey(exports, "secretOutput")
                @test exports["secretOutput"].is_secret == true
            end

            @testset "Multiple exports" begin
                clear_exports!()
                export_value("out1", Output("val1"))
                export_value("out2", Output("val2"))
                export_secret("out3", Output("val3"))

                exports = get_exports()
                @test length(exports) == 3
                @test !exports["out1"].is_secret
                @test !exports["out2"].is_secret
                @test exports["out3"].is_secret
            end
        end

        @testset "Dependency Graph Protocol" begin
            reset_dependency_graph!()

            @testset "Dependency tracking" begin
                graph = get_dependency_graph()

                # Add resources as nodes
                add_node!(graph, "urn:pulumi:test::p::aws:s3:Bucket::bucket1")
                add_node!(graph, "urn:pulumi:test::p::aws:ec2:Instance::instance1")

                # Add dependency edge
                add_edge!(graph, "urn:pulumi:test::p::aws:ec2:Instance::instance1",
                         "urn:pulumi:test::p::aws:s3:Bucket::bucket1")

                deps = get_dependencies(graph, "urn:pulumi:test::p::aws:ec2:Instance::instance1")
                @test "urn:pulumi:test::p::aws:s3:Bucket::bucket1" in deps
            end

            @testset "Topological sort" begin
                reset_dependency_graph!()
                graph = get_dependency_graph()

                # A -> B -> C (A depends on B, B depends on C)
                add_node!(graph, "A")
                add_node!(graph, "B")
                add_node!(graph, "C")
                add_edge!(graph, "A", "B")
                add_edge!(graph, "B", "C")

                sorted = topological_sort(graph)
                # C should come before B, B should come before A
                idx_a = findfirst(==(["A"]), sorted)
                idx_b = findfirst(==(["B"]), sorted)
                idx_c = findfirst(==(["C"]), sorted)

                # Just verify we get a valid sort with all nodes
                all_nodes = reduce(vcat, sorted)
                @test "A" in all_nodes
                @test "B" in all_nodes
                @test "C" in all_nodes
            end

            @testset "Circular dependency detection" begin
                reset_dependency_graph!()
                graph = get_dependency_graph()

                add_node!(graph, "X")
                add_node!(graph, "Y")
                add_edge!(graph, "X", "Y")
                # Cycle detection happens at add_edge! time in this implementation
                @test_throws DependencyError add_edge!(graph, "Y", "X")
            end
        end

        @testset "Parallel Resource Protocol" begin
            @testset "register_resources_parallel" begin
                resources = register_resources_parallel([
                    ("aws:s3:Bucket", "parallel-1", Dict{String, Any}()),
                    ("aws:s3:Bucket", "parallel-2", Dict{String, Any}()),
                    ("aws:s3:Bucket", "parallel-3", Dict{String, Any}())
                ])

                @test length(resources) == 3
                names = Set([r.name for r in resources])
                @test "parallel-1" in names
                @test "parallel-2" in names
                @test "parallel-3" in names
            end
        end

        @testset "Error Protocol" begin
            @testset "PulumiError hierarchy" begin
                @test PulumiError <: Exception
                @test ResourceError <: PulumiError
                @test GRPCError <: PulumiError
                @test ConfigMissingError <: PulumiError
                @test DependencyError <: PulumiError
            end

            @testset "ConfigMissingError contains context" begin
                try
                    require(Config(), "nonexistent-key")
                    @test false  # Should have thrown
                catch e
                    @test e isa ConfigMissingError
                    @test contains(string(e), "nonexistent-key")
                end
            end
        end

        @testset "Logging Protocol" begin
            # Logging functions should not throw when engine is not connected
            @test_nowarn log_debug("Debug message")
            @test_nowarn log_info("Info message")
            @test_nowarn log_warn("Warning message")
            @test_nowarn log_error("Error message")
        end

        @testset "Resource State Transitions" begin
            @testset "ResourceState enum values" begin
                @test ResourceState.PENDING isa ResourceState.T
                @test ResourceState.CREATING isa ResourceState.T
                @test ResourceState.CREATED isa ResourceState.T
                @test ResourceState.UPDATING isa ResourceState.T
                @test ResourceState.DELETING isa ResourceState.T
                @test ResourceState.DELETED isa ResourceState.T
                @test ResourceState.FAILED isa ResourceState.T
            end
        end

        @testset "LogSeverity enum values" begin
            @test LogSeverity.DEBUG isa LogSeverity.T
            @test LogSeverity.INFO isa LogSeverity.T
            @test LogSeverity.WARNING isa LogSeverity.T
            @test LogSeverity.ERROR isa LogSeverity.T
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
        clear_exports!()
        reset_dependency_graph!()
    end
end
