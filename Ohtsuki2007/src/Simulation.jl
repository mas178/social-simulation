module Simulation

using Dates: format, now
using Graphs
using Random: rand
using StatsBase: sample, Weights
using Statistics: mean

function make_graph(N::Int, h::Int, g::Int, l::Int)::Tuple{SimpleGraph, SimpleGraph, SimpleGraph}
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
            isempty(dst_candidates) && break
            dst = rand(dst_candidates)
            add_edge!(graph_H, node, dst)
        end
    end

    # such that G has connectivity g, H has connectivity h, and L has connectivity l.
    for node in vertices(graph_H)
        while degree(graph_H, node) > h
            dst_candidates = neighbors(graph_G, node) ∩ neighbors(graph_H, node)
            dst_candidates = [n for n in dst_candidates if degree(graph_H, n) > h]
            isempty(dst_candidates) && break
            dst = rand(dst_candidates)
            rem_edge!(graph_H, node, dst)
        end
    end

    duplicate_edges = edges(graph_G) ∩ edges(graph_H)
    graph_L = SimpleGraph(N)
    for edge in duplicate_edges
        add_edge!(graph_L, edge)
    end

    return graph_H, graph_G, graph_L
end

mutable struct Agent
    id::Int
    is_cooperator::Bool
    payoff::Float64
    fitness::Float64
    Agent(id::Int) = new(id, id == 1, 0.0, 0.0)
end

mutable struct Model
    N::Int
    b::Float64  # benefit multiplying factor
    c::Float64  # game contribution
    graph_H::SimpleGraph{Int64}
    graph_G::SimpleGraph{Int64}
    agents::Vector{Agent}
end

function Model(N::Int, h::Int, g::Int, l::Int, b::Float64)::Model
    graph_H, graph_G, _ = make_graph(N, h, g, l)
    agents = [Agent(id) for id in 1:N]
    return Model(N, b, 1.0, graph_H, graph_G, agents)
end

function get_agent_by_id(model::Model, id::Int)::Agent
    return [agent for agent in model.agents if agent.id == id][1]
end

function cooperator_rate(model::Model)::Float64
    return mean([agent.is_cooperator for agent in model.agents])
end

function calc_payoffs!(model::Model)
    for agent in model.agents
        opponent_id = rand(neighbors(model.graph_H, agent.id))
        opponenet = get_agent_by_id(model, opponent_id)
        if agent.is_cooperator && opponenet.is_cooperator
            agent.payoff += (model.b - model.c)
            opponenet.payoff += (model.b - model.c)
        elseif agent.is_cooperator && !opponenet.is_cooperator
            agent.payoff -= model.c
            opponenet.payoff += model.b
        elseif !agent.is_cooperator && opponenet.is_cooperator
            agent.payoff += model.b
            opponenet.payoff -= model.c
        end
    end
end

function calc_fitness!(model::Model, w::Float64 = 0.1)
    for agent in model.agents
        agent.fitness = 1 - w + w * agent.payoff
    end
end

function death_birth!(model::Model)
    dying_agent = rand(model.agents)
    neighbors_id = neighbors(model.graph_G, dying_agent.id)
    neighbors_agent = [get_agent_by_id(model, id) for id in neighbors_id]
    parent_agent = sample(neighbors_agent, Weights([agent.fitness for agent in neighbors_agent]))
    dying_agent.is_cooperator = parent_agent.is_cooperator
end

function reset_agents!(model::Model)
    for agent in model.agents
        agent.payoff = 0.0
        agent.fitness = 0.0
    end
end

function run_one_trial(N::Int, h::Int, g::Int, l::Int, b::Float64)::Float64
    model = Model(N, h, g, l, b)

    while true
        calc_payoffs!(model)
        calc_fitness!(model)
        death_birth!(model)
        reset_agents!(model)
        if cooperator_rate(model) == 0.0 || cooperator_rate(model) == 1.0
            return cooperator_rate(model)
        end
    end
end

function run()
    _now = format(now(), "yyyymmdd_HHMMSS")
    file_name = "data/$(_now).csv"

    N = 100
    trial = 100000

    h_g_l_list = h_g_l_list = [(6, 6, 2), (8, 4, 2), (4, 8, 2), (8, 6, 2), (6, 8, 2)]
    b_list = [10, 12.5, 15, 17.5, 20]
    simulation_pattern = vec(collect(Base.product(h_g_l_list, b_list)))

    open(file_name, "w") do io
        for ((h, g, l), b) in simulation_pattern
            println((h, g, l, b))
            result = 0.0
            for _ in 1:trial
                result += run_one_trial(N, h, g, l, b)
            end
            println(io, join([h, g, l, b, result / trial], ","))
            flush(io)
        end
    end
end

# julia src/Simulation.jl
if abspath(PROGRAM_FILE) == @__FILE__
    using .Simulation
    Simulation.run()
end
end
