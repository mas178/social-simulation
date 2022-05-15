module NetworkTest
using Graphs
using Statistics: mean, std
using Test

include("../src/Network.jl")
const nwk = Network  # alias

println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")


@testset "make_graph" begin
    function show_graph(graph_list::Vector)
        for graph in graph_list
            @show mean(degree(graph)), std(degree(graph))
        end
    end

    N = 100
    h_g_l_list = [(6, 6, 2), (8, 4, 2), (4, 8, 2), (8, 6, 2), (6, 8, 2)]
    for (h, g, l) in h_g_l_list
        @show (h, g, l)
        graph_H, graph_G, graph_L = nwk.make_graph(N, h, g, l)
        @test nv(graph_G) == nv(graph_H) == nv(graph_L) == N
        @test is_connected(graph_G) && is_connected(graph_H)
        show_graph([graph_H, graph_G, graph_L])
    end
end
end