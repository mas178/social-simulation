module Simulation

using Dates: format, now
using Graphs
using Random: rand, seed!
using StatsBase: sample, Weights
using Statistics: mean, std

@enum Strategy C D

mutable struct Agent
    id::Int
    strategy::Strategy
    next_strategy::Strategy
    payoff::Float64
    fitness::Float64

    Agent(id::Int) = new(id, rand([C, D]), D, 0.0, 0.0)
end

@enum InteractionRule PairWise Group
@enum UpdateRule BD DB IM

mutable struct Model
    graph::SimpleGraph{Int64}
    h_G::Int  # game interaction globality / locality parameter
    h_R::Int  # adaptation (learning) globality / locality parameter
    b::Float64  # benefit multiplying factor
    c::Float64  # game contribution
    μ::Float64  # mutation rate
    δ::Float64  # selectin parameter
    interaction_rule::InteractionRule
    update_rule::UpdateRule
    agents::Vector{Agent}
    neighbours_game::Vector{Vector{Agent}}  # neighbors for game. That includes myself.
    neighbours_learning::Vector{Vector{Agent}}  # neighbors for learning. That includes myself.
end

function Model(
    graph::SimpleGraph{Int64};
    h_G::Int,
    h_R::Int,
    b::Float64,
    μ::Float64,
    δ::Float64,
    interaction_rule::InteractionRule,
    update_rule::UpdateRule
)::Model
    agents = [Agent(id) for id in vertices(graph)]
    neighbours_game = [[agents[_id] for _id in neighborhood(graph, id, h_G) if _id != id] for id in vertices(graph)]
    neighbours_learning = [[agents[_id] for _id in neighborhood(graph, id, h_R) if _id != id] for id in vertices(graph)]
    return Model(graph, h_G, h_R, b, 1.0, μ, δ, interaction_rule, update_rule, agents, neighbours_game, neighbours_learning)
end

cooperator_rate(model::Model)::Float64 = mean([agent.strategy == C for agent in model.agents])

get_agent_by_id(model::Model, id::Int)::Agent = [agent for agent in model.agents if agent.id == id][1]

pairwise_fermi(πᵢ::Float64, πⱼ::Float64, κ::Float64 = 0.1)::Float64 = 1 / (1 + exp((πᵢ - πⱼ) / κ))

function calc_payoffs!(model::Model)
    if model.interaction_rule == PairWise
        for agent in model.agents
            # Scale-Free Networks Provide a Unifying Framework for the Emergence of Cooperation (Santos & Pacheco, 2005)
            for opponent in model.neighbours_game[agent.id]
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
    elseif model.interaction_rule == Group
        for agent in model.agents
            _game_group = [model.neighbours_game[agent.id]; agent]
            cooperator_count = length(filter(_agent -> _agent.strategy == C, _game_group))
            payoff = model.c * cooperator_count * model.b / length(_game_group)

            for _agent in _game_group
                contribution = _agent.strategy == C ? model.c : 0.0
                _agent.payoff += (payoff - contribution)
            end
        end
    else
        throw(DomainError(interaction_rule, "interaction_rule is invalid."))
    end
end

function update_fitness!(model::Model)
    for agent in model.agents
        agent.fitness = 1 - model.δ + model.δ * agent.payoff
    end
end

function update_strategies!(model::Model)
    if model.update_rule == BD
        # Birth-death
        # 各時間ステップ毎に各個体はその適応度に比例して繁殖のために選ばれる。
        role_model_agent = sample(model.agents, Weights([agent.fitness for agent in model.agents]))
        # 子はランダムに選ばれた隣人を置き換える。
        dying_agent = rand(model.neighbours_learning[role_model_agent.id])
        dying_agent.next_strategy = role_model_agent.strategy
    elseif model.update_rule == DB
        # Death-birth
        for agent in model.agents
            # 隣人たちは、彼らの適応度に比例した強さで、空き地を巡って競争する。
            role_model_agent = sample(model.neighbours_learning[agent.id], Weights([a.fitness for a in model.neighbours_learning[agent.id]]))
            agent.next_strategy = role_model_agent.strategy
        end
    elseif model.update_rule == IM
        # Imitation
        for agent in model.agents
            role_model_agent = rand(model.neighbours_learning[agent.id])
            # 個体はそれぞれの適応度に比例した確率で、自身の戦略に留まるか隣人の戦略を模倣する。
            # Pairwise-Fermi Comparison
            probability_of_imitation = pairwise_fermi(agent.payoff, role_model_agent.payoff, model.δ)
            if probability_of_imitation > rand()
                agent.next_strategy = role_model_agent.strategy
            end
        end
    else
        throw(DomainError(update_rule, "update_rule is invalid."))
    end

    # Mutation
    for agent in model.agents
        agent.strategy = model.μ > rand() ? rand([C, D]) : agent.strategy
    end
end

function update_agents!(model::Model)
    for agent in model.agents
        agent.strategy = agent.next_strategy
        agent.payoff = 0.0
        agent.fitness = 0.0
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
    elseif network_type == :complete
        complete_graph(N)
    else
        throw(DomainError(network_type, "network_type is invalid."))
    end
end

function run()
    println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

    trial_count = 48
    agent_count = 10^3  # 10^4
    generations = 10^6  # 10^5
    network_type_list = [:regular_4, :random_4, :scale_free_4]  # :regular_4, :random_4, :scale_free_4
    h_G_list = [1, 2, 3, 4, 5, 6]  # 1, 2, 3, 4, 5, 6
    h_R_list = [1, 2, 3, 4, 5, 6]  # 1, 2, 3, 4, 5, 6
    b_list = [1.1, 1.2, 1.3, 1.4, 1.5]  # [4.0, 4.5, 5.0, 5.5, 6.0] [1.1, 1.2, 1.3, 1.4, 1.5]
    μ_list = [0.0, 0.01]
    δ_list = [0.01, 0.1, 0.5, 1.0]  # [0.0625, 0.25, 1.0] [0.01, 0.1, 0.5, 1.0]
    interaction_rule_list = [PairWise]  # [PairWise, Group]
    update_rule_list = [BD, DB, IM]

    simulation_pattern = vec(collect(Base.product(network_type_list, h_G_list, h_R_list, b_list, μ_list, δ_list, interaction_rule_list, update_rule_list)))
    println("simulation_pattern: $(length(simulation_pattern))")

    _now = format(now(), "yyyymmdd_HHMMSS")
    mkdir("data/$(_now)")

    Threads.@threads for trial in 1:trial_count
        file_name = "data/$(_now)/$(trial).csv"
        println("file_name: $(file_name)")
        counter = 0

        open(file_name, "w") do io
            @time for (network_type, h_G, h_R, b, μ, δ, interaction_rule, update_rule) in simulation_pattern
                # Generate model
                seed!(abs(rand(Int)))
                graph = make_graph(network_type, agent_count)
                model = Model(graph; h_G=h_G, h_R=h_R, b=b, μ=μ, δ=δ, interaction_rule=interaction_rule, update_rule=update_rule)

                # Output initial status of cooperator_rate
                param_str = join([network_type, h_G, h_R, b, μ, δ, interaction_rule, update_rule, trial], ",")
                # println(io, join([param_str, 0, cooperator_rate(model)], ","))
                cooperator_rate_list = []

                # Run simulation
                for step in 1:generations
                    # if μ != 0.0 || 0 < cooperator_rate(model) < 1  # if all-C or all-D, skip all process.
                    if 0 < cooperator_rate(model) < 1  # if all-C or all-D, skip all process.
                        calc_payoffs!(model)
                        update_fitness!(model)
                        update_strategies!(model)
                        update_agents!(model)
                    end

                    # Log
                    if step >= generations * 0.9
                        push!(cooperator_rate_list, cooperator_rate(model))
                    end
                end
                println(io, join([param_str, mean(cooperator_rate_list)], ","))
                flush(io)

                # show progress
                counter += 1
                if counter % 100 == 0
                    println("$(format(now(), "HH:MM:SS")) $(file_name) $(counter / length(simulation_pattern) * 100)%")
                end
            end
        end
    end
end

function analyze_networks()
    network_type_list = [:scale_free_4, :regular_4, :random_4]
    hop_list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    N = 1000

    network_pattern = vec(collect(Base.product(hop_list, network_type_list)))

    file_name = "data/degrees.csv"
    open(file_name, "w") do io
        for (hop, network_type) in network_pattern
            graph = make_graph(network_type, N)
            model = Model(graph; h_G=hop, h_R=1, b=0.0, μ=0.0, δ=0.0, interaction_rule=PairWise, update_rule=BD)
            for _id in 1:N
                for agent in model.neighbours_game[_id]
                    println(io, join([network_type, hop, _id, agent.id], ","))
                end
            end
        end
    end
end

end  # module end

# cd ~/Dropbox/workspace/inaba2023a
# julia --threads 8 src/Simulation.jl &
# julia src/Simulation.jl &
# nohup julia --threads 8 src/Simulation.jl > out.log &
if abspath(PROGRAM_FILE) == @__FILE__
    using .Simulation
    Simulation.run()

    # Simulation.analyze_networks()
end
