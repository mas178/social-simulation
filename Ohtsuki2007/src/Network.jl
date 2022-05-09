module Network
using Graphs

function make_graph(N::Int, h::Int, g::Int, l::Int)::Tuple{SimpleGraph, SimpleGraph, Float64}
    # (h, g, l) = (8, 4, 2)
    # The procedure to generate them is straightforward: given values of h, g, l,
    # we start by constructing a random regular graph of degree g, ensuring that it is connected. 
    graph_G = random_regular_graph(N, g)
    graph_H = deepcopy(graph_G)
    @assert is_connected(graph_G)

    # Subsequently, we augment this graph by increasing the connectivity of all nodes by h−l,
    for node in vertices(graph_H)
        while degree(graph_H, node) < (g + h - l)
            dst_candidates = setdiff(vertices(graph_H), neighborhood(graph_H, node, 1))
            dst_candidates = [n for n in dst_candidates if degree(graph_H, n) < (g + h - l)]
            if isempty(dst_candidates)
                break
            end
            dst = rand(dst_candidates)
            add_edge!(graph_H, node, dst)
        end
    end

    # such that G has connectivity g, H has connectivity h, and L has connectivity l.
    for node in vertices(graph_H)
        while degree(graph_H, node) > h
            dst_candidates = neighbors(graph_G, node) ∩ neighbors(graph_H, node)
            dst_candidates = [n for n in dst_candidates if degree(graph_H, n) > h]
            if isempty(dst_candidates)
                break
            end
            dst = rand(dst_candidates)
            rem_edge!(graph_H, node, dst)
        end
    end

    duplicate_ratio = length(edges(graph_G) ∩ edges(graph_H)) / length(edges(graph_G) ∪ edges(graph_H))

    graph_G, graph_H, duplicate_ratio
end
end