# In this version, "hop" is model parameter.
module Simulation

using Dates: format, now
using LightGraphs
using Random: rand, shuffle
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

    n_game::Int  # count of game partner
    n_learning::Int  # count of learning partner

    b::Float64  # benefit multiplying factor
    c::Float64  # game contribution

    μ::Float64  # mutation rate

    agents::Vector{Agent}
    neighbours_game::Vector{Vector{Int64}}  # neighbors for game. That includes myself.
    neighbours_learning::Vector{Vector{Int64}}  # neighbors for learning. That includes myself.

    Model(
        graph::SimpleGraph{Int64};
        hop_game::Int,
        hop_learning::Int,
        n_game::Int,
        n_learning::Int,
        b::Float64,
        μ::Float64
    ) = new(
        graph,
        hop_game,
        hop_learning,
        n_game,
        n_learning,
        b,  # benefit multiplying factor
        1.0,  # c: game contribution
        μ,  # mutation rate
        [Agent(id) for id in vertices(graph)],
        [filter(n_id -> n_id != id, neighborhood(graph, id, hop_game)) for id in vertices(graph)],
        [filter(n_id -> n_id != id, neighborhood(graph, id, hop_learning)) for id in vertices(graph)]
    )
end

cooperator_rate(model::Model)::Float64 = mean([agent.is_cooperator for agent in model.agents])

function select_neighbours(model::Model, agent::Agent, context::Symbol)::Vector{Agent}
    neighbour_ids, n = if context == :game
        model.neighbours_game[agent.id], model.n_game
    elseif context == :learning
        model.neighbours_learning[agent.id], model.n_learning
    else
        throw(DomainError(context, "context is invalid."))
    end

    neighbour_ids = length(neighbour_ids) > n ? shuffle(neighbour_ids)[1:n] : neighbour_ids
    push!(neighbour_ids, agent.id)
    return [model.agents[n_id] for n_id in neighbour_ids]
end

function calc_payoffs!(model::Model)
    Threads.@threads for agent in model.agents
        neighbours = select_neighbours(model, agent, :game)
        cooperator_count = length(filter(_agent -> _agent.is_cooperator, neighbours))
        payoff = model.c * cooperator_count * model.b / length(neighbours)

        for _agent in neighbours
            contribution = _agent.is_cooperator ? model.c : 0.0
            _agent.payoff += (payoff - contribution)
        end
    end
end

function set_next_strategies!(model::Model)
    Threads.@threads for agent in model.agents
        neighbours = select_neighbours(model, agent, :learning)
        best_payoff_agent = sort(neighbours, by = _agent -> _agent.payoff, rev = true)[1]
        agent.next_is_cooperator = best_payoff_agent.is_cooperator
    end
end

function update_agents!(model::Model)
    Threads.@threads for agent in model.agents
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
        random_regular_graph(N, 4)
    else
        throw(DomainError(network_type, "network_type is invalid."))
    end
end

function str(graph::SimpleGraph)::String
    edge_list = ["[$(edge.src),$(edge.dst)]" for edge in edges(graph)]
    join(edge_list, ",")
end

function run()
    println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

    trial_count = 100
    agent_count = 10^3
    generations = 10^3

    network_type_list = [:scale_free_4]
    hop_game_list = [1]
    hop_learning_list = [1, 2, 5]
    n_game_list = [4]
    n_learning_list = [4]
    b_list = [2.0, 3.0]
    μ = 0.00

    simulation_pattern = [(network_type, hop_game, hop_learning, n_game, n_learning, b) for network_type in network_type_list for hop_game in hop_game_list for hop_learning in hop_learning_list for n_game in n_game_list for n_learning in n_learning_list for b in b_list]
    println("simulation_pattern: $(length(simulation_pattern))")

    _now = format(now(), "yyyymmdd_HHMMSS")
    file_name = "data/$(_now).csv"
    println("file_name: $(file_name)")

    @time for trial in 1:trial_count
        println("trial: $(trial)")

        file = open(file_name, "a")   # 開けたり閉じたりしすぎるとパフォーマンス劣化。開けっ放しにし過ぎると長時間のシミュレーションで不安定。

        @time for (network_type, hop_game, hop_learning, n_game, n_learning, b) in simulation_pattern
            # Generate model
            graph = make_graph(network_type, agent_count)
            model = Model(graph; hop_game=hop_game, hop_learning=hop_learning, n_game=n_game, n_learning=n_learning, b=b, μ=μ)

            # Output initial status of cooperator_rate
            println(file, join([network_type, hop_game, hop_learning, n_game, n_learning, b, trial, 0, cooperator_rate(model)], ","))

            # Run simulation
            for step in 1:generations
                if 0 < cooperator_rate(model) < 1  # if all-C or all-D, skip all process.
                    calc_payoffs!(model)
                    set_next_strategies!(model)
                    update_agents!(model)
                end

                # Output cooperator_rate every 20 steps.
                step % 20 == 0 && println(file, join([network_type, hop_game, hop_learning, n_game, n_learning, b, trial, step, cooperator_rate(model)], ","))
            end
        end

        close(file)
    end
end

function run_detail()
    println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

    trial_count = 100
    agent_count = 10^3
    generations = 10^3

    network_type = :scale_free_4
    hop_game = 1
    n_game = 4
    n_learning = 4
    μ = 0.01

    b_list = [2.0, 3.0]
    hop_learning_list = [1, 2, 5]

    simulation_pattern = [(hop_learning, b) for hop_learning in hop_learning_list for b in b_list]

    # file names
    _now = format(now(), "yyyymmdd_HHMMSS")
    file_name_detail = "data/$(_now)_detail.csv"

    # file open
    file_detail = open(file_name_detail, "w")

    @time for trial in 1:trial_count
        println("trial: $(trial)")
        @time for (hop_learning, b) in simulation_pattern
            # Generate model
            model = Model(make_graph(network_type, agent_count); hop_game=hop_game, hop_learning=hop_learning, n_game=n_game, n_learning=n_learning, b=b, μ=μ)

            # Run simulation
            for step in 1:generations
                calc_payoffs!(model)
                set_next_strategies!(model)

                # save payoff and strategy
                for agent in model.agents
                    println(file_detail, join([
                        b,
                        hop_learning,
                        trial,
                        step,
                        agent.id,
                        agent.is_cooperator ? "C" : "D",
                        round(agent.payoff, digits=3),
                        degree(model.graph, agent.id)
                    ], ","))
                end

                update_agents!(model)
            end
        end
    end

    close(file_detail)
end

end  # module end

if abspath(PROGRAM_FILE) == @__FILE__
    using .Simulation
    # Simulation.run()
    Simulation.run_detail()
end
