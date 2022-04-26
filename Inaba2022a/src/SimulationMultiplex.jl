module Simulation

using Dates: format, now
using LightGraphs
using Random: rand, shuffle
using Statistics: mean

mutable struct Agent
    id::Int
    is_cooperator::Bool
    next_is_cooperator::Bool
    payoff::Float64

    Agent(id::Int) = new(id, rand([true, false]), false, 0.0)
end

struct Model
    graph_game::SimpleGraph{Int64}
    graph_learning::SimpleGraph{Int64}

    n_game::Int  # count of game partner
    n_learning::Int  # count of learning partner

    b::Float64  # benefit multiplying factor
    c::Float64  # game contribution

    μ::Float64  # mutation rate

    agents::Vector{Agent}
    neighbours_game::Vector{Vector{Int64}}  # neighbors for game
    neighbours_learning::Vector{Vector{Int64}}  # neighbors for learning
end

function Model(graph_game::SimpleGraph{Int64}, graph_learning::SimpleGraph{Int64};
    n_game::Int, n_learning::Int, b::Float64, μ::Float64 = 0.0)::Model

    Model(
        graph_game,
        graph_learning,
        n_game,
        n_learning,
        b,  # benefit multiplying factor
        1.0,  # c: game contribution
        μ,  # mutation rate
        [Agent(id) for id in vertices(graph_game)],
        [neighbors(graph_game, id) for id in vertices(graph_game)],
        [neighbors(graph_learning, id) for id in vertices(graph_learning)]
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
    for agent in model.agents
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
    for agent in model.agents
        neighbours = select_neighbours(model, agent, :learning)
        best_payoff_agent = sort(neighbours, by = _agent -> _agent.payoff, rev = true)[1]
        agent.next_is_cooperator = best_payoff_agent.is_cooperator
    end
end

function update_agents!(model::Model)
    for agent in model.agents
        agent.is_cooperator = model.μ > rand() ? rand([true, false]) : agent.next_is_cooperator
        agent.payoff = 0.0
    end
end

function make_graph(network_type::Symbol, N::Int)::SimpleGraph
    if network_type == :scale_free_2
        barabasi_albert(N, 1, complete = true)
    elseif network_type == :scale_free_4
        barabasi_albert(N, 2, complete = true)
    elseif network_type == :scale_free_6
        barabasi_albert(N, 3, complete = true)
    elseif network_type == :scale_free_8
        barabasi_albert(N, 4, complete = true)
    elseif network_type == :regular_2
        random_regular_graph(N, 2)
    elseif network_type == :regular_4
        random_regular_graph(N, 4)
    elseif network_type == :regular_6
        random_regular_graph(N, 6)
    elseif network_type == :regular_8
        random_regular_graph(N, 8)
    elseif network_type == :complete
        complete_graph(N)
    else
        throw(DomainError(network_type, "network_type is invalid."))
    end
end

function run()
    println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

    trial_count = 100
    agent_count = 10^3
    generations = 10^3

    network_type_game_list = [:scale_free_4]
    network_type_learning_list = [:scale_free_4, :complete]
    n_game_list = [4]
    n_learning_list = [4]
    b_list = [2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]

    simulation_pattern = [(network_type_game, network_type_learning, n_game, n_learning, b) for network_type_game in network_type_game_list for network_type_learning in network_type_learning_list for n_game in n_game_list for n_learning in n_learning_list for b in b_list]
    println("simulation_pattern: $(length(simulation_pattern))")

    file_name = "data/mplx$(format(now(), "yyyymmdd_HHMMSS")).csv"
    println("file_name: $(file_name)")

    @time for trial in 1:trial_count
        println("trial: $(trial)")
        open(file_name, "a") do file  # 開けたり閉じたりしすぎるとパフォーマンス劣化。開けっ放しにし過ぎると長時間のシミュレーションで不安定。
            @time for (network_type_game, network_type_learning, n_game, n_learning, b) in simulation_pattern
                # Generate graph
                graph_game = make_graph(network_type_game, agent_count)
                graph_learning = make_graph(network_type_learning, agent_count)

                # Generate model
                model = Model(graph_game, graph_learning; n_game=n_game, n_learning=n_learning, b=b, μ = 0.0)

                # Output initial status of cooperator_rate
                println(file, join([network_type_game, network_type_learning, n_game, n_learning, b, trial, 0, cooperator_rate(model)], ","))

                # Run simulation
                for step in 1:generations
                    if 0 < cooperator_rate(model) < 1  # if all-C or all-D, skip all process.
                        calc_payoffs!(model)
                        set_next_strategies!(model)
                        update_agents!(model)
                    end

                    # Output cooperator_rate every 20 steps.
                    if step % 20 == 0
                        println(file, join([network_type_game, network_type_learning, n_game, n_learning, b, trial, step, cooperator_rate(model)], ","))
                    end
                end
            end
        end
    end
end

end  # module end

if abspath(PROGRAM_FILE) == @__FILE__
    using .Simulation
    Simulation.run()
end
