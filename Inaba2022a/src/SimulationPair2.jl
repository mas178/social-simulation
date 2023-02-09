module Simulation

using Agents
using Graphs
using Statistics: mean, sum

@enum Strategy C D

mutable struct Player <: AbstractAgent
    id::Int
    pos::Int
    strategy::Strategy
    next_strategy::Strategy
    payoff::Float64
    Player(id::Int) = new(id, id, rand([C, D]), D, 0.0)
end

cooperator_rate(model::AgentBasedModel)::Float64 = mean([agent.strategy == C for agent in allagents(model)])

function play(b_r::Float64, me::Player, you::Player)::Float64
    payoff = nothing
    
    if (me.strategy, you.strategy) == (C, C)
        payoff = 1.0
    elseif (me.strategy, you.strategy) == (C, D)
        payoff = 0.0
    elseif (me.strategy, you.strategy) == (D, C)
        payoff = b_r
    elseif (me.strategy, you.strategy) == (D, D)
        payoff = 0.00001
    end
    
    return payoff
end

function build_model(;G::SimpleGraph, b_r::Float64)
    space = GraphSpace(G)
    model = ABM(Player, space, properties = Dict(:b_r => b_r))

    # モデル上にエージェントを配置する。
    for id in 1:nv(G)
        add_agent_pos!(Player(id), model)
    end
    
    return model
end

function model_step!(model::AgentBasedModel)
    b_r = model.properties[:b_r]
    
    # In each generation, all pairs of individuals x and y, directly connected, engage in a single round of a given game,
    # their accumulated payoffs being stored as Px and Py, respectively.
    for agent in allagents(model)
        agent.payoff = 0
        for neighbor in nearby_agents(agent, model)
            agent.payoff += play(b_r, agent, neighbor)
        end
    end
    
    # decide next strategy by pay-off
    for agent in allagents(model)
        # Whenever a site x is updated, a neighbor y is drawn at random among all kx neighbors
        neighbors = nearby_agents(agent, model)
        neighbor_count = length(neighbors)
        neighbor = collect(neighbors)[rand(1:neighbor_count)]
        
        # whenever Py > Px the chosen neighbor takes over site x with probability given by (Py−Px)/(Dk>)
        # where k> is the largest between kx and ky and D=T−S for the PD and D=T−P for the SG
        Px = agent.payoff
        Py = neighbor.payoff
        D = b_r
        kx = neighbor_count
        ky = length(nearby_agents(neighbor, model))
        take_over_ratio = (Py - Px) / (D * max(kx, ky))
        
        if Py > Px && take_over_ratio > rand()
            agent.next_strategy = neighbor.strategy
        else
            agent.next_strategy = agent.strategy
        end
    end
    
    # update strategy
    for agent in allagents(model)
        agent.strategy = agent.next_strategy
    end
end

function run_simulation(; b_r::Float64, N::Int = 10^2, k::Int = 4, N_trials::Int = 10)::Float64
    N_gen = 10^4
    f_c = 0
    for _ in 1:N_trials
        model = build_model(;G = barabasi_albert(N, k), b_r = b_r)
        run!(model, dummystep, model_step!, N_gen)
        f_c += cooperator_rate(model)
    end

    return f_c / N_trials
end

for b_r in 1.1:0.2:1.7
    println([b_r, run_simulation(; b_r)])
end
end

# cd ~/Dropbox/workspace/social-simulation/Inaba2022a
# julia src/SimulationPair2.jl
if abspath(PROGRAM_FILE) == @__FILE__
    using .Simulation
end
