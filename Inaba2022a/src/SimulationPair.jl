module Simulation

using Graphs
using Statistics: mean

@enum Strategy C D

mutable struct Agent
    id::Int
    strategy::Strategy
    next_strategy::Strategy
    payoff::Float64
    Agent(id::Int) = new(id, rand([C, D]), D, 0.0)
end

mutable struct Model
    graph::SimpleGraph{Int64}
    b::Float64  # benefit multiplying factor
    agents::Vector{Agent}
    Model(graph::SimpleGraph{Int64}, b::Float64)::Model = new(graph, b, [Agent(id) for id in vertices(graph)])
end

cooperator_rate(model::Model)::Float64 = mean([agent.strategy == C for agent in model.agents])

get_agent_by_id(model::Model, id::Int)::Agent = [agent for agent in model.agents if agent.id == id][1]

pairwise_fermi(πᵢ::Float64, πⱼ::Float64, κ::Float64 = 0.1)::Float64 = 1 / (1 + exp((πᵢ - πⱼ) / κ))

function calc_payoffs!(model::Model)
    for agent in model.agents
        for opponent_id in neighbors(model.graph, agent.id)
            opponent = get_agent_by_id(model, opponent_id)
            if (agent.strategy, opponent.strategy) == (C, C)
                agent.payoff += 1.0  # R
            elseif (agent.strategy, opponent.strategy) == (C, D)
                agent.payoff += 0  # S
            elseif (agent.strategy, opponent.strategy) == (D, C)
                agent.payoff += model.b  # T
            elseif (agent.strategy, opponent.strategy) == (D, D)
                agent.payoff += 0.00001  # P
            end
        end
    end
end

function update_strategies!(model::Model)
    for agent in model.agents
        neighbors_ = neighbors(model.graph, agent.id)
        neighbor = get_agent_by_id(model, rand(neighbors_))

        Px = agent.payoff
        Py = neighbor.payoff
        # kx = length(neighbors_)
        # ky = length(neighbors(model.graph, neighbor.id))
        # D = model.b
        # take_over_ratio = (Py - Px) / (D * max(kx, ky))

        take_over_ratio = pairwise_fermi(Px, Py)

        if Py > Px && take_over_ratio > rand()
            agent.next_strategy = neighbor.strategy
        else
            agent.next_strategy = agent.strategy
        end
    end
end

function update_agents!(model::Model)
    for agent in model.agents
        agent.strategy = agent.next_strategy
        agent.payoff = 0.0
    end
end

function run()
    println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

    trial_count = 10
    agent_count = 10^3  # 10^4
    generations = 10^4  # 10^5
    for b in 1.1:0.2:1.7
        for trial in 1:trial_count
            # Generate model
            graph = barabasi_albert(agent_count, 2, complete = true)
            model = Model(graph, b)
    
            # Run simulation
            for step in 1:generations
                calc_payoffs!(model)
                update_strategies!(model)
                update_agents!(model)
            end
            println(join([trial, b, cooperator_rate(model)], ","))
        end
    end
end
end  # module end

# cd ~/Dropbox/workspace/social-simulation/Inaba2022a
# julia src/SimulationPair.jl
if abspath(PROGRAM_FILE) == @__FILE__
    using .Simulation
    Simulation.run()
end
