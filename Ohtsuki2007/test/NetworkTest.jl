module NetworkTest
using Graphs
using Statistics: mean, std
using Test

include("../src/Network.jl")
const nwk = Network  # alias

println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

@testset "make_graph" begin
    N = 100
    graph_G, graph_H, duplicate_ratio = nwk.make_graph(N, 6, 6, 2)
    @test nv(graph_G) == nv(graph_H) == N
    @test is_connected(graph_G) && is_connected(graph_H)
    @show mean(degree(graph_G)), std(degree(graph_G))
    @show mean(degree(graph_H)), std(degree(graph_H))
    @show duplicate_ratio

    graph_G, graph_H, duplicate_ratio = nwk.make_graph(N, 8, 4, 2)
    @test nv(graph_G) == nv(graph_H) == N
    @test is_connected(graph_G) && is_connected(graph_H)
    @show mean(degree(graph_H)), std(degree(graph_H))
    @show mean(degree(graph_G)), std(degree(graph_G))
    @show duplicate_ratio

    graph_G, graph_H, duplicate_ratio = nwk.make_graph(N, 4, 8, 2)
    @test nv(graph_G) == nv(graph_H) == N
    @test is_connected(graph_G) && is_connected(graph_H)
    @show mean(degree(graph_H)), std(degree(graph_H))
    @show mean(degree(graph_G)), std(degree(graph_G))
    @show duplicate_ratio

    graph_G, graph_H, duplicate_ratio = nwk.make_graph(N, 8, 6, 2)
    @test nv(graph_G) == nv(graph_H) == N
    @test is_connected(graph_G) && is_connected(graph_H)
    @show mean(degree(graph_H)), std(degree(graph_H))
    @show mean(degree(graph_G)), std(degree(graph_G))
    @show duplicate_ratio

    graph_G, graph_H, duplicate_ratio = nwk.make_graph(N, 6, 8, 2)
    @test nv(graph_G) == nv(graph_H) == N
    @test is_connected(graph_G) && is_connected(graph_H)
    @show mean(degree(graph_H)), std(degree(graph_H))
    @show mean(degree(graph_G)), std(degree(graph_G))
    @show duplicate_ratio
end
end