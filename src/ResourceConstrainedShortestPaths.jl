module ResourceConstrainedShortestPaths

using Distances
using DataStructures

include("utils.jl")

export Resource
export AdditiveResource
export TimeWindowResource
export ElementaryResource
export is_monotone
export RCSPP
export shortest_paths

export generate_adjlist
export return_shortest_paths

abstract type Resource end


struct AdditiveResource{T <: Real} <: Resource
    name::Symbol
    values::Matrix{T}
    lb::T
    ub::T
    type::Type{T}
    function AdditiveResource{T}(
        name::Symbol,
        values::Matrix{T},
        lb::T,
        ub::T,
    ) where {T <: Real}
        @assert name != :cost
        @assert isless(-Inf, lb)
        @assert isless(ub, Inf)
        @assert size(values, 1) == size(values, 2)
        new{T}(
            name,
            values,
            lb,
            ub,
            T,
        )
    end
end

AdditiveResource(
    name::Symbol, 
    values::Matrix{T}, 
    lb::T,
    ub::T,
    ;
) where {T <: Real} = AdditiveResource{T}(name, values, lb, ub)
AdditiveResource(
    name::Symbol, 
    values::Matrix{T}, 
    ub::T,
    ;
) where {T <: Real} = AdditiveResource{T}(name, values, zero(T), ub)
AdditiveResource(
    name::Symbol, 
    values::Vector{T},
    lb::T,
    ub::T,
    ;
) where {T <: Real} = begin
    values = values |> x -> repeat(x, inner = [1, length(values)]) |> transpose |> Matrix
    AdditiveResource{T}(name, values, lb, ub)
end
AdditiveResource(
    name::Symbol, 
    values::Vector{T},
    ub::T,
    ;
) where {T <: Real} = AdditiveResource{T}(name, values, zero(T), ub)

is_monotone(ref::AdditiveResource{T}) where {T} = all(ref.values .≥ zero(T))



function get_next_resource_value(
    res::AdditiveResource{T}, 
    current_resource_value::T, 
    current_node::Int, 
    next_node::Int,
) where {T}
    new_resource_value = current_resource_value + res.values[current_node, next_node]
    if new_resource_value > res.ub
        return current_resource_value, false
    else
        return new_resource_value, true
    end
end

struct TimeWindowResource{T <: Real} <: Resource
    name::Symbol
    values::Matrix{T}
    lb::T
    ub::T
    start_times::Vector{T}
    end_times::Vector{T}
    type::Type{T}
    function TimeWindowResource{T}(
        values::Matrix{T},
        lb::T,
        ub::T,
        start_times::Vector{T},
        end_times::Vector{T},
        ;
        name::Symbol = :time,
    ) where {T <: Real}
        @assert name != :cost
        @assert isless(-Inf, lb)
        @assert isless(ub, Inf)
        @assert size(values, 1) == size(values, 2) == size(start_times, 1) == size(end_times, 1)
        @assert all(lb .≤ start_times .≤ end_times .≤ ub)
        @assert all(values .≥ zero(T))
        new{T}(
            name,
            values,
            lb,
            ub,
            start_times,
            end_times,
            T,
        )
    end
end

TimeWindowResource(
    values::Matrix{T}, 
    lb::T,
    ub::T,
    start_times::Vector{T},
    end_times::Vector{T},
    ;
    name::Symbol = :time,
) where {T <: Real} = TimeWindowResource{T}(values, lb, ub, start_times, end_times; name = name)
TimeWindowResource(
    values::Matrix{T}, 
    ub::T,
    start_times::Vector{T},
    end_times::Vector{T},
    ;
    name::Symbol = :time,
) where {T <: Real} = TimeWindowResource{T}(values, zero(T), ub, start_times, end_times; name = name)



is_monotone(ref::TimeWindowResource{T}) where {T} = true

# implement
function get_next_resource_value(
    res::TimeWindowResource{T}, 
    current_resource_value::T, 
    current_node::Int, 
    next_node::Int,
) where {T}
    new_resource_value = max(
        current_resource_value + res.values[current_node, next_node],
        res.start_times[next_node],
    )
    if new_resource_value > res.end_times[next_node]
        return current_resource_value, false
    else
        return new_resource_value, true
    end
end


struct ElementaryResource <: Resource
    name::Symbol
    n_nodes::Int
    customers # collection
    lb::BitVector
    ub::BitVector
    type::Type{BitVector}
    function ElementaryResource(
        name::Symbol,
        n_nodes::Int,
        customers,
    )
        @assert eltype(customers) == Int # can be a AbstractVector{Int} or a Abstract{Int} or a AbstractRange{Int}
        new(
            name,
            n_nodes,
            customers,
            falses(n_nodes),
            trues(n_nodes),
            BitVector,
        )
    end
end

ElementaryResource(name::Symbol, n_nodes::Int) = ElementaryResource(name, n_nodes, 1:n_nodes)
ElementaryResource(n_nodes::Int) = ElementaryResource(:served, n_nodes, 1:n_nodes)
ElementaryResource(n_nodes::Int, customers) = ElementaryResource(:served, n_nodes, customers)

# implement
function get_next_resource_value(
    res::ElementaryResource, 
    current_resource_value::BitVector, 
    current_node::Int, 
    next_node::Int,
)   
    # only perform this check if next_node in res.customers?
    if next_node in res.customers && current_resource_value[next_node]
        return current_resource_value, false
    end
    new_resource_value = copy(current_resource_value)
    new_resource_value[next_node] = true
    return new_resource_value, true
end

dominates(v1::T, v2::T) where {T <: Real} = v1 ≤ v2
dominates(v1::BitVector, v2::BitVector) = all(v1 .≤ v2)
dominates(k1::Tuple, k2::Tuple) = all(dominates(v1, v2) for (v1, v2) in zip(k1, k2))

struct RCSPP
    adjlists::Vector{Vector{Int}}
    resources::Vector{<:Resource} # Assume the first resource is time
    src::Int
    dst::Int
    keytype::Type{<:Tuple}
    function RCSPP(
        adjlists::Vector{Vector{Int}},
        resources::Vector{<:Resource},
        src::Int,
        dst::Int,
    )
        # check resource is monotonic 
        @assert length(resources) ≥ 1
        @assert is_monotone(resources[1])
        keytype = Tuple{vcat([r.type for r in resources], [Float64])...}
        new(
            adjlists,
            resources,
            src,
            dst,
            keytype,
        )
    end
end

RCSPP(adj::BitMatrix, resources, src::Int, dst::Int) = RCSPP(convert_bitarray_to_adjlist(adj), resources, src, dst)
RCSPP(adj::Matrix{Bool}, resources, src::Int, dst::Int) = RCSPP(convert_bitarray_to_adjlist(convert(BitMatrix, adj)), resources, src, dst)
RCSPP(adj::Matrix{Int}, resources, src::Int, dst::Int) = RCSPP(convert_bitarray_to_adjlist(convert(BitMatrix, adj)), resources, src, dst)

function _get_start_key(
    prob::RCSPP,
)
    return Tuple(vcat([
        r.lb
        for r in prob.resources
    ], [0.0]))
end

function _extend_path_label(
    prob::RCSPP,
    current_key::Tuple,
    current_node_seq::Vector{Int},
    costs::Matrix{Float64},
    current_node::Int,
    next_node::Int,
)
    new_key = Any[]
    for (i, resource) in enumerate(prob.resources)
        new_resource_val, feasible = get_next_resource_value(resource, current_key[i], current_node, next_node)
        if !feasible
            return (current_key, current_node_seq, false)
        end
        push!(new_key, new_resource_val)
    end
    push!(new_key, current_key[end] + costs[current_node, next_node])
    return (
        Tuple(new_key),
        vcat(current_node_seq, next_node),
        true,
    )
end

function add_new_path_to_paths!(
    collection::SortedDict{
        T,
        Vector{Int},
        Base.Order.ForwardOrdering,
    },
    key::T, 
    value::Vector{Int},
) where {T <: Tuple}
    added = true
    # println(key, collection)
    for (k, v) in pairs(collection)
        # println(collection)
        if dominates(k, key)
            added = false
            break
        end
        if dominates(key, k)
            pop!(collection, k)
        end
    end
    if added 
        insert!(collection, key, value)
    end
    return added
end

function shortest_paths(
    prob::RCSPP,
    costs::Matrix{Float64},
)
    # initialize data structure and queue

    paths = Dict(
        node => SortedDict{
            prob.keytype, 
            Vector{Int},
            Base.Order.ForwardOrdering,
        }(Base.Order.ForwardOrdering())
        for node in axes(costs, 1)
    )
    unexplored_states = SortedSet{prob.keytype}()
    unexplored_state_nodes = Dict{prob.keytype, Vector{Int}}()
    start_key = _get_start_key(prob)
    for next_node in prob.adjlists[prob.src]
        new_key, new_node_seq, feasible = _extend_path_label(
            prob,
            start_key,
            [prob.src],
            costs,
            prob.src,
            next_node,
        )
        !feasible && continue
        added = add_new_path_to_paths!(
            paths[next_node],
            new_key, new_node_seq,
        )
        if added
            push!(unexplored_states, new_key)
            if !(new_key in keys(unexplored_state_nodes))
                unexplored_state_nodes[new_key] = Int[]
            end
            push!(unexplored_state_nodes[new_key], next_node)
        end
    end

    # label-setting
    while length(unexplored_states) > 0
        current_key = pop!(unexplored_states)
        while length(unexplored_state_nodes[current_key]) > 0
            current_node = pop!(unexplored_state_nodes[current_key])
            if !(current_key in keys(paths[current_node]))
                continue
            end
            current_node_seq = paths[current_node][current_key]
            for next_node in prob.adjlists[current_node]
                new_key, new_node_seq, feasible = _extend_path_label(
                    prob,
                    current_key,
                    current_node_seq,
                    costs,
                    current_node,
                    next_node,
                )
                !feasible && continue
                added = add_new_path_to_paths!(
                    paths[next_node], 
                    new_key, new_node_seq,
                )
                if added
                    push!(unexplored_states, new_key)
                    if !(new_key in keys(unexplored_state_nodes))
                        unexplored_state_nodes[new_key] = Int[]
                    end
                    push!(unexplored_state_nodes[new_key], next_node)
                end
            end
        end
    end

    return paths[prob.dst]

end

end
