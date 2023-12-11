using ResourceConstrainedShortestPaths
using Test
using Distances

@testset "Resources" begin
    res = AdditiveResource(:time, rand(3, 3), 1.0)
    @test isa(res, AdditiveResource)
    res = AdditiveResource(:time, rand(3, 3), 1.0, 2.0)
    @test isa(res, AdditiveResource)
    @test_throws AssertionError AdditiveResource(:cost, rand(3, 3), 1.0, 2.0)
    @test_throws AssertionError AdditiveResource(:time, rand(3, 4), 1.0, 2.0)
    @test_throws AssertionError AdditiveResource(:time, rand(3, 3), -Inf, 2.0)
    @test_throws AssertionError AdditiveResource(:time, rand(3, 3), 1.0, Inf)
    @test is_monotone(res)

    start_times = fill(0.2, (3,))
    end_times = fill(0.8, (3,))
    res = TimeWindowResource(rand(3, 3), 0.0, 1.0, start_times, end_times)
    @test isa(res, TimeWindowResource)
    @test_throws AssertionError TimeWindowResource(rand(3, 3), 0.0, 1.0, start_times, end_times, name = :cost)
    @test_throws AssertionError TimeWindowResource(rand(3, 3), -Inf, 1.0, start_times, end_times)
    @test_throws AssertionError TimeWindowResource(rand(3, 3), 0.0, Inf, start_times, end_times)
    @test_throws AssertionError TimeWindowResource(rand(3, 4), 0.0, 1.0, start_times, end_times)
    @test_throws AssertionError TimeWindowResource(rand(3, 3), 0.0, 1.0, fill(0.2, (4,)), fill(0.8, (4,)))
    @test_throws AssertionError TimeWindowResource(rand(3, 3), 0.0, 1.0, end_times, start_times)
    @test_throws AssertionError TimeWindowResource(rand(3, 3), 0.4, 1.0, start_times, end_times)
    @test_throws AssertionError TimeWindowResource(rand(3, 3), 0.0, 0.6, start_times, end_times)
    # @test_throws AssertionError TimeWindowResource(rand(3, 3), 0.0, 1.0, start_times, end_times)
    @test is_monotone(res)
end

@testset "ResourceConstrainedShortestPaths.jl" begin
    # Write your tests here.
    using ResourceConstrainedShortestPaths
    include("../src/utils.jl")
    n_customers = 10
    coords = rand(2, n_customers + 1)
    coords = hcat(coords, coords[:,1])
    distances = pairwise(Euclidean(), coords, dims = 2)

    A = ones(n_customers + 2, n_customers + 2)
    A[:,1] .= 0
    A[end,:] .= 0
    A[1,end] = 0
    for i in axes(A, 1)
        A[i, i] = 0
    end

    adjlists = convert_bitarray_to_adjlist(convert(BitMatrix, A))
    @test_throws MethodError convert_bitarray_to_adjlist(A)
    @assert adjlists == generate_adjlist(n_customers)

    times = distances ./ 2
    start_times = rand(10) ./ 2
    end_times = rand(10) ./ 2 .+ .5
    ub = 1.0
    start_times = vcat([0.0], start_times, [0.0])
    end_times = vcat([1.0], end_times, [1.0])
    println(size(times))
    println(size(start_times))
    println(size(start_times))
    time_rec = TimeWindowResource(times, ub, start_times, end_times)
    load = Int.(round.(rand(10) .* 3))
    load = vcat([0], load, [0])
    capacity = 4
    load_rec = AdditiveResource(:load, load, 0, capacity)
    elem_rec = ElementaryResource(n_customers + 2, 2:n_customers + 1)
    resources = [
        time_rec,
        load_rec,
        elem_rec,
    ]
    prob = RCSPP(adjlists, resources, 1, n_customers + 2)

    # using DataStructures
    # s = SortedDict{
    #     prob.keytype, 
    #     Vector{Int},
    #     Base.Order.ForwardOrdering,
    # }(Base.Order.ForwardOrdering())

    reduced_costs = copy(distances)
    duals = rand(n_customers) .* 5
    for i in eachindex(duals)
        reduced_costs[:, i+1] .-= duals[i]
    end
    @show reduced_costs
    s = shortest_paths(prob, reduced_costs)
    println(s)
end
