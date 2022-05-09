# In this version, "hop" is model parameter.
module Simulation

using Dates: format, now
using Graphs
using Random: rand, shuffle
using StatsBase: sample, Weights
using Statistics: mean, std

mutable struct Agent
    id::Int
    is_cooperator::Bool
    next_is_cooperator::Bool
    payoff::Float64

    Agent(id::Int) = new(id, rand([true, false]), false, 0.0)
end

struct Model
    graph::SimpleGraph{Int64}
    hop_game::Int  # game interaction globality / locality parameter
    hop_learning::Int  # adaptation (learning) globality / locality parameter
    b::Float64  # benefit multiplying factor
    c::Float64  # game contribution
    μ::Float64  # mutation rate
    δ::Float64  # selectin parameter
    agents::Vector{Agent}
    neighbours_game::Vector{Vector{Agent}}  # neighbors for game. That includes myself.
    neighbours_learning::Vector{Vector{Agent}}  # neighbors for learning. That includes myself.
end

function Model(
    graph::SimpleGraph{Int64};
    hop_game::Int,
    hop_learning::Int,
    b::Float64,
    μ::Float64,
    δ::Float64
)::Model
    agents = [Agent(id) for id in vertices(graph)]
    neighbours_game = [[agents[_id] for _id in neighborhood(graph, id, hop_game)] for id in vertices(graph)]
    neighbours_learning = [[agents[_id] for _id in neighborhood(graph, id, hop_learning)] for id in vertices(graph)]
    return Model(graph, hop_game, hop_learning, b, 1.0, μ, δ, agents, neighbours_game, neighbours_learning)
end


cooperator_rate(model::Model)::Float64 = mean([agent.is_cooperator for agent in model.agents])

function calc_payoffs!(model::Model; calc_pattern::Int = 1)
    """
    1: そのまま
    2: ペイオフを隣人数で割る (一回のゲームで得られる平均ペイオフを最終的なペイオフとする)
    3: 拠出金を隣人数で割る (拠出金の合計が1になるようにする)
    """
    if calc_pattern == 1 || calc_pattern == 2
        for agent in model.agents
            cooperator_count = length(filter(_agent -> _agent.is_cooperator, model.neighbours_game[agent.id]))
            payoff = model.c * cooperator_count * model.b / length(model.neighbours_game[agent.id])
    
            for _agent in model.neighbours_game[agent.id]
                contribution = _agent.is_cooperator ? model.c : 0.0
                _agent.payoff += (payoff - contribution)
            end
        end
        if calc_pattern == 2
            for agent in model.agents
                agent.payoff /= length(model.neighbours_game[agent.id])
            end
        end
    else
        for agent in model.agents
            contributions = [neighbor.is_cooperator ? model.c / length(model.neighbours_game[neighbor.id]) : 0.0 for neighbor in model.neighbours_game[agent.id]]
            payoff = sum(contributions) * model.b / length(model.neighbours_game[agent.id])

            for (_agent, contribution) in zip(model.neighbours_game[agent.id], contributions)
                _agent.payoff += (payoff - contribution)
            end
        end
    end
end

payoff_to_fitness(payoff::Float64, δ::Float64) = round(1 - δ + δ * payoff, digits=3)

function role_model(model::Model, agent::Agent, weak_selection::Bool)::Agent
    role_model = if weak_selection
        # weak-selection rule
        weights = [payoff_to_fitness(a.payoff, model.δ) for a in model.neighbours_learning[agent.id]]
        sample(model.neighbours_learning[agent.id], Weights(weights))
    else
        # take-the-best rule
        sort(model.neighbours_learning[agent.id], by = _agent -> _agent.payoff, rev = true)[1]
    end

    return role_model
end

function set_next_strategies!(model::Model; weak_selection::Bool = false)
    for agent in model.agents
        agent.next_is_cooperator = role_model(model, agent, weak_selection).is_cooperator
    end
end

function update_agents!(model::Model)
    for agent in model.agents
        agent.is_cooperator = model.μ > rand() ? rand([true, false]) : agent.next_is_cooperator
        agent.payoff = 0.0
    end
end

function make_graph(network_type::Symbol, N::Int)::SimpleGraph
    if network_type == :scale_free_4
        barabasi_albert(N, 2, complete = true)
    elseif network_type == :scale_free_6
        barabasi_albert(N, 3, complete = true)
    elseif network_type == :scale_free_8
        barabasi_albert(N, 4, complete = true)
    elseif network_type == :regular_4
        x = Int(round(sqrt(N)))
        grid([x, x], periodic=true)
    elseif network_type == :random_4
        g = erdos_renyi(N, 2N)

        # connect unconnected vertices
        components = connected_components(g)
        sort!(components, lt = (a, b) -> length(a) > length(b))
        [add_edge!(g, v, rand(components[1])) for v in 1:N if v ∉ components[1]]

        # remove surplus edges
        while ne(g) > 2N
            v1 = rand(vertices(g))
            v2 = rand(neighbors(g, v1))
            rem_edge!(g, v1, v2)
            if !has_path(g, v1, v2)
                add_edge!(g, v1, v2)
            end
        end

        g
    else
        throw(DomainError(network_type, "network_type is invalid."))
    end
end

function str(graph::SimpleGraph)::String
    edge_list = ["[$(edge.src),$(edge.dst)]" for edge in edges(graph)]
    join(edge_list, ",")
end

function run(;detail::Bool = false)
    println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

    trial_count = 100
    agent_count = 10^3
    generations = 10^3

    # network_type_list = [:scale_free_4, :regular_4, :random_4]
    # weak_selection_list = [true]  # [true, false]
    # calc_payoffs_pattern_list = [1, 2, 3]  # [1, 2, 3]
    # hop_game_list = [1]  # [1, 2, 3, 4, 5]
    # hop_learning_list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]  # [1, 2, 3, 4, 5]
    # b_list = [4.0, 4.5, 5.0, 5.5, 6.0]  # [4.0, 4.5, 5.0, 5.5, 6.0]
    # μ_list = [0.0, 0.01]  # [0.0, 0.01]
    # δ_list = [0.0625, 0.125, 0.25, 0.5, 1.0]  # [0.0625, 0.125, 0.25, 0.5, 1.0]

    network_type_list = [:scale_free_4, :random_4]
    weak_selection_list = [true]
    calc_payoffs_pattern_list = [1]
    hop_game_list = [1]
    hop_learning_list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    b_list = [5.0]
    μ_list = [0.0]
    δ_list = [1.0]

    simulation_pattern = vec(collect(Base.product(network_type_list, weak_selection_list, calc_payoffs_pattern_list, hop_game_list, hop_learning_list, b_list, μ_list, δ_list)))
    println("simulation_pattern: $(length(simulation_pattern))")

    _now = format(now(), "yyyymmdd_HHMMSS")
    mkdir("data/$(_now)")

    Threads.@threads for trial in 1:trial_count
        file_name = "data/$(_now)/$(trial).csv"
        println("file_name: $(file_name)")

        open(file_name, "w") do io
            @time for (network_type, weak_selection, calc_pattern, hop_game, hop_learning, b, μ, δ) in simulation_pattern
                # Generate model
                graph = make_graph(network_type, agent_count)
                model = Model(graph; hop_game=hop_game, hop_learning=hop_learning, b=b, μ=μ, δ=δ)
    
                # Output initial status of cooperator_rate
                param_str = join([network_type, weak_selection, calc_pattern, hop_game, hop_learning, b, μ, δ, trial], ",")
                detail || println(io, join([param_str, 0, cooperator_rate(model)], ","))
    
                # Run simulation
                for step in 1:generations
                    if 0 < cooperator_rate(model) < 1  # if all-C or all-D, skip all process.
                        calc_payoffs!(model, calc_pattern = calc_pattern)
                        set_next_strategies!(model, weak_selection = weak_selection)

                        # save payoff and strategy
                        detail && for agent in model.agents
                            println(io, join([
                                param_str,
                                step, agent.id,
                                agent.is_cooperator, 
                                round(agent.payoff, digits=3),
                                degree(model.graph, agent.id)
                            ], ","))
                        end

                        update_agents!(model)
                    end
    
                    # Output cooperator_rate every 10 steps.
                    (!detail && step % 10 == 0) && println(io, join([param_str, step, cooperator_rate(model)], ","))
                end
                flush(io)
            end
        end    
    end
end
end  # module end

# julia --threads 10 src/Simulation.jl
if abspath(PROGRAM_FILE) == @__FILE__
    using .Simulation
    # Simulation.run()
    Simulation.run(detail = true)
end
