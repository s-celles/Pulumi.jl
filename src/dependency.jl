"""
Dependency graph management for Pulumi resources.

Per constitution's Dependency Graph Correctness principle:
- DAG representation with topological sort for resource ordering
- Automatic dependency extraction from Output references
- Cycle detection with clear error messages
"""

"""
    DependencyGraph

Directed acyclic graph for tracking resource dependencies.
"""
mutable struct DependencyGraph
    # Map from resource URN to set of URNs it depends on
    edges::Dict{String, Set{String}}
    # All registered URNs
    nodes::Set{String}
end

"""
    DependencyGraph()

Create an empty dependency graph.
"""
DependencyGraph() = DependencyGraph(Dict{String, Set{String}}(), Set{String}())

"""
    add_node!(graph::DependencyGraph, urn::String)

Add a node (resource) to the graph.
"""
function add_node!(graph::DependencyGraph, urn::String)
    push!(graph.nodes, urn)
    if !haskey(graph.edges, urn)
        graph.edges[urn] = Set{String}()
    end
end

"""
    add_edge!(graph::DependencyGraph, from::String, to::String)

Add a dependency edge: `from` depends on `to`.

# Arguments
- `graph::DependencyGraph`: The dependency graph
- `from::String`: URN of the dependent resource
- `to::String`: URN of the dependency

# Throws
- `DependencyError`: If adding the edge would create a cycle
"""
function add_edge!(graph::DependencyGraph, from::String, to::String)
    # Ensure both nodes exist
    add_node!(graph, from)
    add_node!(graph, to)

    # Check for immediate cycle
    if from == to
        throw(DependencyError("Resource cannot depend on itself", [from]))
    end

    # Check if adding this edge would create a cycle
    if would_create_cycle(graph, from, to)
        # Find the cycle path for error message
        cycle = find_cycle_path(graph, from, to)
        throw(DependencyError("Adding dependency would create a cycle", cycle))
    end

    push!(graph.edges[from], to)
end

"""
    would_create_cycle(graph::DependencyGraph, from::String, to::String) -> Bool

Check if adding an edge from `from` to `to` would create a cycle.
"""
function would_create_cycle(graph::DependencyGraph, from::String, to::String)::Bool
    # If `to` can reach `from`, adding from->to creates a cycle
    visited = Set{String}()
    return can_reach(graph, to, from, visited)
end

"""
    can_reach(graph::DependencyGraph, start::String, target::String, visited::Set{String}) -> Bool

Check if `target` is reachable from `start` via dependencies.
"""
function can_reach(graph::DependencyGraph, start::String, target::String, visited::Set{String})::Bool
    if start == target
        return true
    end
    if start in visited
        return false
    end
    push!(visited, start)

    deps = get(graph.edges, start, Set{String}())
    for dep in deps
        if can_reach(graph, dep, target, visited)
            return true
        end
    end
    return false
end

"""
    find_cycle_path(graph::DependencyGraph, from::String, to::String) -> Vector{String}

Find the path that would form a cycle if edge from->to is added.
"""
function find_cycle_path(graph::DependencyGraph, from::String, to::String)::Vector{String}
    # Find path from `to` to `from`
    path = String[]
    visited = Set{String}()

    function dfs(current::String)::Bool
        if current == from
            push!(path, current)
            return true
        end
        if current in visited
            return false
        end
        push!(visited, current)

        deps = get(graph.edges, current, Set{String}())
        for dep in deps
            if dfs(dep)
                push!(path, current)
                return true
            end
        end
        return false
    end

    if dfs(to)
        push!(path, to)  # Add the starting point
        reverse!(path)   # Reverse to get correct order
    end

    return path
end

"""
    topological_sort(graph::DependencyGraph) -> Vector{String}

Return resources in topological order (dependencies before dependents).

# Returns
- `Vector{String}`: URNs in order where each resource appears after all its dependencies

# Throws
- `DependencyError`: If the graph contains a cycle
"""
function topological_sort(graph::DependencyGraph)::Vector{String}
    result = String[]
    visited = Set{String}()
    temp_visited = Set{String}()  # For cycle detection

    function visit(urn::String)
        if urn in temp_visited
            # Cycle detected
            throw(DependencyError("Cycle detected in dependency graph", [urn]))
        end
        if urn in visited
            return
        end

        push!(temp_visited, urn)

        # Visit all dependencies first
        deps = get(graph.edges, urn, Set{String}())
        for dep in deps
            if dep in graph.nodes  # Only visit known nodes
                visit(dep)
            end
        end

        delete!(temp_visited, urn)
        push!(visited, urn)
        push!(result, urn)
    end

    for urn in graph.nodes
        visit(urn)
    end

    return result
end

"""
    get_dependencies(graph::DependencyGraph, urn::String) -> Set{String}

Get direct dependencies of a resource.
"""
function get_dependencies(graph::DependencyGraph, urn::String)::Set{String}
    get(graph.edges, urn, Set{String}())
end

"""
    get_all_dependencies(graph::DependencyGraph, urn::String) -> Set{String}

Get all transitive dependencies of a resource.
"""
function get_all_dependencies(graph::DependencyGraph, urn::String)::Set{String}
    result = Set{String}()
    visited = Set{String}()

    function collect(current::String)
        if current in visited
            return
        end
        push!(visited, current)

        deps = get(graph.edges, current, Set{String}())
        for dep in deps
            push!(result, dep)
            collect(dep)
        end
    end

    collect(urn)
    return result
end

"""
    get_dependents(graph::DependencyGraph, urn::String) -> Set{String}

Get resources that directly depend on this resource.
"""
function get_dependents(graph::DependencyGraph, urn::String)::Set{String}
    result = Set{String}()
    for (node, deps) in graph.edges
        if urn in deps
            push!(result, node)
        end
    end
    return result
end

# Global dependency graph for the current program
const _DEPENDENCY_GRAPH = Ref{DependencyGraph}(DependencyGraph())
const _GRAPH_LOCK = ReentrantLock()

"""
    get_dependency_graph() -> DependencyGraph

Get the global dependency graph for the current program.
"""
function get_dependency_graph()::DependencyGraph
    lock(_GRAPH_LOCK) do
        _DEPENDENCY_GRAPH[]
    end
end

"""
    reset_dependency_graph!()

Reset the global dependency graph (for testing).
"""
function reset_dependency_graph!()
    lock(_GRAPH_LOCK) do
        _DEPENDENCY_GRAPH[] = DependencyGraph()
    end
end

"""
    register_dependency!(from::String, to::String)

Register a dependency in the global graph.
"""
function register_dependency!(from::String, to::String)
    lock(_GRAPH_LOCK) do
        add_edge!(_DEPENDENCY_GRAPH[], from, to)
    end
end

"""
    register_resource_dependencies!(urn::String, deps::Vector{String})

Register all dependencies for a resource.
"""
function register_resource_dependencies!(urn::String, deps::Vector{String})
    lock(_GRAPH_LOCK) do
        add_node!(_DEPENDENCY_GRAPH[], urn)
        for dep in deps
            add_edge!(_DEPENDENCY_GRAPH[], urn, dep)
        end
    end
end
