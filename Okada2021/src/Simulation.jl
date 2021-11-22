#=
Simulation:
- Julia version: 
- Author: inaba
- Date: 2021-11-20
=#
module Simulation
using Dates: format, now
using LightGraphs
using Random
using Statistics: mean

mutable struct Agent
    id::Int
    is_cooperator::Bool
    is_punisher::Bool
    next_is_cooperator::Bool
    next_is_punisher::Bool
    payoff::Float64

    Agent(id::Int) = new(id, rand([true, false]), rand([true, false]), false, false, 0.0)
end

struct Model
    agents::Vector{Agent}
    graph::SimpleGraph{Int64}
    hop::Int  # neighbor parameter
    neighbours::Vector{Vector{Int64}}  # neighbors of every nodes

    g::Float64  # game interaction locality parameter
    p::Float64  # punishment locality parameter
    a::Float64  # adaptation (learning) locality parameter

    b::Float64  # benefit of a token
    c::Float64  # game cost
    f::Float64  # fine
    s::Float64  # sanction for punishment

    μ::Float64  # mutation rate

    Model(agents::Vector{Agent}, graph::SimpleGraph; g::Float64, p::Float64, a::Float64) = new(
        agents, graph, 2,
        [[_n for _n in neighborhood(graph, i, 2) if _n != i] for i in vertices(graph)],
        g, p, a,
        2.0, 1.0, 6.0, 3.0, 0.01
    )
end

cooperator_rate(model::Model)::Float64 = mean([agent.is_cooperator for agent in model.agents])
punisher_rate(model::Model)::Float64 = mean([agent.is_punisher for agent in model.agents])

function calc_payoffs!(model::Model)
    n_size = length(model.agents)
    global_cooperator_rate = cooperator_rate(model)
    global_punisher_rate = punisher_rate(model)

    for agent in model.agents
        local_cooperator_rate = mean([model.agents[neighbor].is_cooperator for neighbor in model.neighbours[agent.id]])
        local_punisher_rate = mean([model.agents[neighbor].is_punisher for neighbor in model.neighbours[agent.id]])

        _global_cooperator_rate = (global_cooperator_rate * n_size - Int(agent.is_cooperator)) / (n_size - 1)
        _global_punisher_rate = (global_punisher_rate * n_size - Int(agent.is_punisher)) / (n_size - 1)

        # ゲームの中で協力者が占める割合
        _cooperator_rate = local_cooperator_rate * (1. - model.g) + _global_cooperator_rate * model.g

        # benefit (ゲームの中で協力者が占める割合 (自分を含む))
        _b = (_cooperator_rate * model.hop * 2 + Int(agent.is_cooperator)) / (model.hop * 2 + 1)
        # game cost
        _c = agent.is_cooperator ? 1 : 0
        # sanction (罰を課すコスト)
        _s = agent.is_punisher ? (1 - local_cooperator_rate) * (1 - model.p) + (1 - _global_cooperator_rate) * model.p : 0.0
        # Fine (罰金)
        _f = agent.is_cooperator ? 0.0 : local_punisher_rate * (1 - model.p) + _global_punisher_rate * model.p

        agent.payoff = _b * model.b - _c * model.c - _s * model.s - _f * model.f
    end
end

function set_next_strategies!(model::Model)
    for agent in model.agents
        if rand() < model.μ
            agent.next_is_cooperator = rand([true, false])
            agent.next_is_punisher = rand([true, false])
        else
            y = if rand() < 0.5 # a
                rand([_a.id for _a in model.agents if _a.id != agent.id])
            else
                rand(model.neighbours[agent.id])
            end

            if model.agents[y].payoff > agent.payoff
                agent.next_is_cooperator = model.agents[y].is_cooperator
                agent.next_is_punisher = model.agents[y].is_punisher
            else
                agent.next_is_cooperator = agent.is_cooperator
                agent.next_is_punisher = agent.is_punisher
            end
        end
    end
end

function update_strategies!(model::Model)
    for agent in model.agents
        agent.is_cooperator = agent.next_is_cooperator
        agent.is_punisher = agent.next_is_punisher
    end
end

function run(;
    n_size::Int = 100,
    generation::Int = 100,
    trial::Int = 100,
    gs::Vector = [0.0, 0.25, 0.5, 0.75, 1.0],
    ps::Vector = [0.0, 0.25, 0.5, 0.75, 1.0],
    as::Vector = [0.0, 0.25, 0.5, 0.75, 1.0],
    file_name = "out/jl$(format(now(), "yyyymmdd_HHMMSS")).csv")

    for g = gs, p = ps, a = as
        cooperator_rate_vec = []
        punisher_rate_vec = []
        for t in 1:trial
            agents = [Agent(id) for id in 1:n_size]
            graph = cycle_graph(n_size)
            model = Model(agents, graph; g, p, a)

            for step = 1:generation
                calc_payoffs!(model)
                set_next_strategies!(model)
                update_strategies!(model)
            end

            push!(cooperator_rate_vec, cooperator_rate(model))
            push!(punisher_rate_vec, punisher_rate(model))
        end

        csv = "$(g),$(p),$(a),$(mean(cooperator_rate_vec)),$(mean(punisher_rate_vec))"
        println(csv)
        open(file_name, "a") do out
            println(out, csv)
        end
    end
end
end

if abspath(PROGRAM_FILE) == @__FILE__
    using .Simulation
    Simulation.run()
    # Simulation.run(gs = [0.0], ps = [1.0], as = [0.0])
end
