# Integration tests for stack exports.
#
# `register_stack_outputs` asks the engine for the stack's root URN and then
# publishes every exported value against it, so these tests check the whole
# round trip against the fake engine.

@testitem "Stack Exports Integration" setup=[TestSupport] begin
    @testset "Export values are registered" begin
        TestSupport.with_fake_engine() do engine
            clear_exports!()
            try
                export_value("bucketName", "assets-bucket")
                export_value("replicaCount", 3)

                Pulumi.register_stack_outputs()

                @test length(engine.outputs) == 1
                request = engine.outputs[1]

                # Stack outputs are attached to the root stack resource the
                # SDK registers, not to any resource of the program. A real
                # engine does not report a root resource of its own, which is
                # why `GetRootResource` cannot be used for this.
                @test request.urn == TestSupport.stack_urn()
                @test isempty(engine.root_urn)

                # That root resource really was registered.
                @test Base.any(r -> r.var"#type" == "pulumi:pulumi:Stack", engine.registrations)

                published = Pulumi.struct_to_dict(request.outputs)
                @test published["bucketName"] == "assets-bucket"
                @test published["replicaCount"] == 3
            finally
                clear_exports!()
            end
        end
    end

    @testset "Resource outputs can be exported" begin
        TestSupport.with_fake_engine() do engine
            clear_exports!()
            try
                bucket = register_resource("aws:s3:Bucket", "assets",
                    Dict{String, Any}("acl" => "private"))
                export_value("acl", bucket.outputs["acl"])
                export_value("urn", get_urn(bucket))

                Pulumi.register_stack_outputs()

                published = Pulumi.struct_to_dict(engine.outputs[end].outputs)
                @test published["acl"] == "private"
                @test published["urn"] == "urn:pulumi:dev::test-project::aws:s3:Bucket::assets"
            finally
                clear_exports!()
            end
        end
    end

    @testset "Secrets are published in a secret envelope" begin
        TestSupport.with_fake_engine() do engine
            clear_exports!()
            try
                export_secret("dbPassword", "hunter2")
                export_value("dbUser", "admin")

                Pulumi.register_stack_outputs()

                published = Pulumi.struct_to_dict(engine.outputs[end].outputs)

                # The secret travels wrapped so the engine knows to encrypt it.
                @test Pulumi.is_secret_value(published["dbPassword"])
                @test Pulumi.unwrap_secret(published["dbPassword"]) == "hunter2"

                # A plain value is not wrapped.
                @test published["dbUser"] == "admin"
            finally
                clear_exports!()
            end
        end
    end

    @testset "Nothing is published when nothing is exported" begin
        TestSupport.with_fake_engine() do engine
            clear_exports!()
            Pulumi.register_stack_outputs()
            @test isempty(engine.outputs)
        end
    end
end

@testitem "Running a program publishes its exports" setup=[TestSupport] begin
    # The Pulumi CLI never calls `register_stack_outputs` itself, so running a
    # program has to do it: otherwise `pulumi stack output` comes back empty
    # however many values the program exported.
    @testset "run_program registers the stack outputs" begin
        TestSupport.with_fake_engine() do engine
            clear_exports!()
            try
                mktempdir() do dir
                    program = joinpath(dir, "main.jl")
                    write(program, """
                    using Pulumi
                    export_value("greeting", "hello from Julia")
                    export_value("answer", 42)
                    """)

                    Pulumi.run_program(program)

                    @test length(engine.outputs) == 1
                    published = Pulumi.struct_to_dict(engine.outputs[1].outputs)
                    @test published["greeting"] == "hello from Julia"
                    @test published["answer"] == 42
                end
            finally
                clear_exports!()
            end
        end
    end

    @testset "The program runs in Main, not inside Pulumi" begin
        TestSupport.with_fake_engine() do engine
            clear_exports!()
            try
                mktempdir() do dir
                    program = joinpath(dir, "main.jl")
                    write(program, "some_program_local_name = 1\n")

                    Pulumi.run_program(program)

                    # A binding created while this method is running belongs to
                    # a newer world age, so it has to be looked up with
                    # `invokelatest`.
                    @test Base.invokelatest(isdefined, Main, :some_program_local_name)
                    @test !Base.invokelatest(isdefined, Pulumi, :some_program_local_name)
                end
            finally
                clear_exports!()
            end
        end
    end

    @testset "A failing program propagates the error" begin
        TestSupport.with_fake_engine() do engine
            clear_exports!()
            try
                mktempdir() do dir
                    program = joinpath(dir, "main.jl")
                    write(program, "error(\"boom\")\n")

                    @test_throws Exception Pulumi.run_program(program)
                    # Nothing is published for a program that failed.
                    @test isempty(engine.outputs)
                end
            finally
                clear_exports!()
            end
        end
    end

    @testset "A missing program is reported" begin
        TestSupport.with_fake_engine() do _
            @test_throws ArgumentError Pulumi.run_program(joinpath(tempdir(), "nope-$(rand(UInt32)).jl"))
        end
    end
end
