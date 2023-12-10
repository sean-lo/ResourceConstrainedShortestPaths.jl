function convert_bitarray_to_adjlist(adj::Union{Matrix{Bool}, BitMatrix})
    return [findall(adj[i,:]) for i in axes(adj, 1)]
end