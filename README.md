# ResourceConstrainedShortestPaths

[![Build Status](https://github.com/sean-lo/ResourceConstrainedShortestPaths.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/sean-lo/ResourceConstrainedShortestPaths.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/sean-lo/ResourceConstrainedShortestPaths.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/sean-lo/ResourceConstrainedShortestPaths.jl)

A general algorithm for resource-constrained shortest path problems in Julia, which returns multiple shortest paths.

The Resource-Constrained Shortest Path Problem (RCSPP) occurs frequently as the subproblem of a column generation approach for routing problems such as VRP, VRPTW, CVRPTW. In those settings, one wishes to find paths with negative reduced cost to add to the restricted master problem. This is traditionally done via shortest-paths algorithms which return a single path obeying the resource constraints, via dynamic programming; however, one can use the same DP algorithm to obtain multiple shortest paths, and add all such paths with negative reduced cost to the master problem.

Given a directed graph $G = (V, E)$, a source and destination $s, t \in V$, this algorithm returns all $s$-$t$ paths which are *non-dominated* with respect to each other. Each path has an associated *label*, which is a vector of resource values per resource; *domination* refers to the label of one path being componentwise smaller ($\leq$) than the label of another path.

## Usage

For example, to solve the subproblem for the Capacitated VRP with Time Windows, one might use the following resources:
- A time resource (via `TimeWindowResource`) which computes the time vehicles arrive at nodes, taking into account time window constraints, and prevents paths from exceeding the time horizon.
- A load resource (via the generic `AdditiveResource`) which tracks the load that vehicles carry at nodes, and prevents paths from exceeding capacity.
- An elementary service requirement (via the binary vector `ElementaryResource`) which tracks the number of times the path has served each customer, and prevents paths from serving customers more than once.

```julia
using ResourceConstrainedShortestPaths
# Initialize the problem
prob = RCSPP(
    adjlists,           # adjacency list representation of G
    [
        TimeWindowResource(times, ub, start_times, end_times),
        AdditiveResource(:load, load, 0, capacity),
        ElementaryResource(n_customers + 2, 2:n_customers + 1),
    ],
    1,                  # source node
    n_customers + 2,    # destination node
)
# Get all non-dominated shortest paths from source to destination, according to costs
# One can call `shortest_paths` with different values of `costs`
paths = shortest_paths(prob, costs)
```

## Differences with other software:
- [`cspy`](https://github.com/torressa/cspy): This package supports multiple resources, a variety of REFs and the ability to write custom REFs, but only yields one shortest path. In contrast, we yield the set of non-dominated paths from source to destination (this makes our algorithm slower).
- [`ConstrainedShortestPaths.jl`](https://github.com/BatyLeo/ConstrainedShortestPaths.jl)Also allows multiple resources and custom REFs. Only applies to acyclic directed graphs, and only returns one path. 

## Defining your own custom resource
To define your own resource, one needs to implement the following interface:
```julia
using ResourceConstrainedShortestPaths
struct YourResource <: Resource 
    name::Symbol # convenience
end
is_monotone(res::YourResource) = false # TODO: this is the default
function get_next_resource_value(
    res::YourResource, 
    current_resource_value::T,
    current_node::Int,
    next_node::Int,
)  
    # TODO: check if extension is feasible according to this resource,
    # else return current_resource_value, false
    # TODO: compute new_resource_value 
    return new_resource_value, true
end
dominates(k1::T, k2::T) = false # TODO if your resource value type T is not <:Real or a BitVector

```

## Future releases

- Backwards labelling, bi-directional labelling
- More commonly-encountered resources e.g. `NGRouteResource`
- A custom implementation of `NonDominatedDict <: SortedDict` which allows:
    - indexing by key (raising `KeyError` if the key is not found)
    - iteration over key-value pairs
    - `push!(c, key=>val)` which efficiently removes all keys `k` dominated by `key`

## Contributing

Pull requests are welcomed!