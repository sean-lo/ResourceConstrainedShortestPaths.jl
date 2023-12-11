function convert_bitarray_to_adjlist(adj::Union{Matrix{Bool}, BitMatrix})
    return [findall(adj[i,:]) for i in axes(adj, 1)]
end

function generate_adjlist(n_customers::Int)
    # Assumes that the customers are 2:n+1, and the source and the sink are 1 and n+2 respectively.
    adjlists = Vector{Int}[
        collect(setdiff(2:n_customers+2, i))
        for i in 2:n_customers+1
    ]
    pushfirst!(adjlists, collect(2:n_customers+1))
    push!(adjlists, Int[])
    return adjlists
end