@testset "Dependency Graph" begin
    @testset "Basic graph operations" begin
        graph = DependencyGraph()

        # Add nodes
        add_node!(graph, "a")
        add_node!(graph, "b")
        add_node!(graph, "c")
        @test "a" in graph.nodes
        @test "b" in graph.nodes
        @test "c" in graph.nodes

        # Add edges (b depends on a, c depends on b)
        add_edge!(graph, "b", "a")
        add_edge!(graph, "c", "b")
        @test "a" in get_dependencies(graph, "b")
        @test "b" in get_dependencies(graph, "c")
    end

    @testset "Topological sort" begin
        graph = DependencyGraph()
        add_node!(graph, "a")
        add_node!(graph, "b")
        add_node!(graph, "c")
        add_node!(graph, "d")

        # d -> c -> b -> a (d depends on c, c on b, b on a)
        add_edge!(graph, "b", "a")
        add_edge!(graph, "c", "b")
        add_edge!(graph, "d", "c")

        sorted = topological_sort(graph)
        @test length(sorted) == 4

        # a must come before b, b before c, c before d
        idx_a = findfirst(==(("a")), sorted)
        idx_b = findfirst(==(("b")), sorted)
        idx_c = findfirst(==(("c")), sorted)
        idx_d = findfirst(==(("d")), sorted)

        @test idx_a < idx_b
        @test idx_b < idx_c
        @test idx_c < idx_d
    end

    @testset "Cycle detection" begin
        graph = DependencyGraph()
        add_node!(graph, "a")
        add_node!(graph, "b")
        add_edge!(graph, "b", "a")  # b depends on a

        # Self-cycle
        @test_throws DependencyError add_edge!(graph, "a", "a")

        # Simple cycle: a -> b -> a
        @test_throws DependencyError add_edge!(graph, "a", "b")

        # Three-node cycle
        graph2 = DependencyGraph()
        add_edge!(graph2, "b", "a")
        add_edge!(graph2, "c", "b")
        @test_throws DependencyError add_edge!(graph2, "a", "c")
    end

    @testset "Transitive dependencies" begin
        graph = DependencyGraph()
        add_edge!(graph, "b", "a")
        add_edge!(graph, "c", "b")
        add_edge!(graph, "d", "c")
        add_edge!(graph, "d", "a")  # d also directly depends on a

        # Direct dependencies
        @test get_dependencies(graph, "d") == Set(["c", "a"])

        # All transitive dependencies
        all_deps = get_all_dependencies(graph, "d")
        @test "a" in all_deps
        @test "b" in all_deps
        @test "c" in all_deps
        @test length(all_deps) == 3
    end

    @testset "Get dependents" begin
        graph = DependencyGraph()
        add_edge!(graph, "b", "a")
        add_edge!(graph, "c", "a")
        add_edge!(graph, "d", "b")

        # What depends on a?
        dependents_a = get_dependents(graph, "a")
        @test "b" in dependents_a
        @test "c" in dependents_a
        @test !("d" in dependents_a)

        # What depends on b?
        dependents_b = get_dependents(graph, "b")
        @test "d" in dependents_b
    end

    @testset "Global dependency graph" begin
        reset_dependency_graph!()

        graph = get_dependency_graph()
        @test graph isa DependencyGraph
        @test isempty(graph.nodes)

        # Register dependencies
        register_dependency!("resource-b", "resource-a")
        register_resource_dependencies!("resource-c", ["resource-a", "resource-b"])

        graph = get_dependency_graph()
        @test "resource-a" in graph.nodes
        @test "resource-b" in graph.nodes
        @test "resource-c" in graph.nodes
        @test "resource-a" in get_dependencies(graph, "resource-c")
        @test "resource-b" in get_dependencies(graph, "resource-c")

        # Reset
        reset_dependency_graph!()
        graph = get_dependency_graph()
        @test isempty(graph.nodes)
    end

    @testset "Diamond dependency" begin
        # Common pattern: a -> b, a -> c, b -> d, c -> d
        graph = DependencyGraph()
        add_edge!(graph, "b", "a")
        add_edge!(graph, "c", "a")
        add_edge!(graph, "d", "b")
        add_edge!(graph, "d", "c")

        sorted = topological_sort(graph)
        idx_a = findfirst(==(("a")), sorted)
        idx_b = findfirst(==(("b")), sorted)
        idx_c = findfirst(==(("c")), sorted)
        idx_d = findfirst(==(("d")), sorted)

        # a must come before b and c
        @test idx_a < idx_b
        @test idx_a < idx_c
        # b and c must come before d
        @test idx_b < idx_d
        @test idx_c < idx_d
    end
end
