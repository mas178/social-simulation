module Simulation
    using LinearAlgebra
    using Dates: format, now

    # Action
    const C = Int8(1)
    const D = Int8(0)

    # Reputation Logic
    const Heider = Int8(2)
    const Friend_Focused = Int8(1)
    const All_D = Int8(0)
    const Reputation_Logic_List = (Heider, Friend_Focused, All_D)

    mutable struct Agent
        id::Int
        action::Int8
        reputation_logic::Int8
        payoff::Float64

        Agent(id::Int) = new(id, D, All_D, 0.0)
    end

    mutable struct Model
        n::Int
        steps_per_generation::Int
        generations::Int
        b::Float64
        c::Float64
        r::Float64
        u::Float64
        agents::Vector{Agent}
        reputation_matrix::Matrix{Float64}
    end

    function Model()::Model
        n = 100
        steps_per_generation = 10
        generations = 4 * 10^5
        b = 4.0
        c = 1.0
        r = 0.3
        u = 0.01
        agents = [Agent(id) for id in 1:n]
        reputation_matrix = Matrix{Float64}(I, n, n)

        return Model(n, steps_per_generation, generations, b, c, r, u, agents, reputation_matrix)
    end

    reset_agents_payoff!(model::Model) = for agent in model.agents
        agent.payoff = 0.0
    end

    function calc_relationship_score(model::Model, agent::Agent, opponent::Agent)::Float64
        # 行ベクトル mx (関係ベクトル) は自分 (agent) と他の全エージェントとの関係を表す。
        mx = model.reputation_matrix[agent.id:agent.id, :]

        # 列ベクトル nx (評判ベクトル) はゲームの相手 (opponent) が全エージェントからどう思われているかを表す。
        ny = model.reputation_matrix[:, opponent.id:opponent.id]

        if agent.reputation_logic == Heider
            # ハイダーエージェント x は、エージェント y とペアになったとき、評価ベクトル ny をとり、
            # 各要素 i (エージェント i の y に対する意見) にそれぞれのエージェント i との関係を乗じ、
            # 関係スコア rs = mx × ny となる。
            rs = (mx * ny)[1, 1]
        elseif agent.reputation_logic == Friend_Focused
            # 友人とは、関係 sxi > 0 のエージェントである。
            # 友人重視型エージェントの関係ベクトルは、𝐦′𝑥 = max {0, mx} に置き換えられる。
            # 関係スコア rs = 𝐦′𝑥 × ny は、友人の意見に基づいて重み付けして集約されたものである。
            # つまり、友人じゃないエージェントの意見は無視する。
            _mx = mx .* (mx .> 0)
            rs = (_mx * ny)[1, 1]
        elseif agent.reputation_logic == All_D
            rs = -1.0
        else
            throw(DomainError(agent.reputation_logic, "agent.reputation_logic is wrong."))
        end

        return rs
    end

    # 関係スコアrs は、ロジスティック決定関数に基づいてCを選択する確率を決定する。
    c_probability(rs::Float64)::Float64 = 1 / (1 + exp(-rs / 0.2))

    action(rs::Float64)::Int8 = c_probability(rs) > rand() ? C : D

    function set_action!(model::Model, agent_x::Agent, agent_y::Agent)::Nothing
        relationship_score_xy = calc_relationship_score(model, agent_x, agent_y)
        relationship_score_yx = calc_relationship_score(model, agent_y, agent_x)
        agent_x.action = action(relationship_score_xy)
        agent_y.action = action(relationship_score_yx)
        return
    end

    function calc_payoff!(model::Model, agent_x::Agent, agent_y::Agent)::Nothing
        if (agent_x.action, agent_y.action) == (C, C)
            agent_x.payoff += model.b - model.c
            agent_y.payoff += model.b - model.c
        elseif (agent_x.action, agent_y.action) == (C, D)
            agent_x.payoff -= model.c
            agent_y.payoff += model.b
        elseif (agent_x.action, agent_y.action) == (D, C)
            agent_x.payoff += model.b
            agent_y.payoff -= model.c
        end

        return
    end

    function update_reputation_matrix!(model::Model, agent_x::Agent, agent_y::Agent)::Nothing
        if (agent_x.action, agent_y.action) == (C, C)
            model.reputation_matrix[agent_x.id, agent_y.id] += model.r
            model.reputation_matrix[agent_y.id, agent_x.id] += model.r
        elseif (agent_x.action, agent_y.action) == (C, D)
            model.reputation_matrix[agent_x.id, agent_y.id] -= model.r
        elseif (agent_x.action, agent_y.action) == (D, C)
            model.reputation_matrix[agent_y.id, agent_x.id] -= model.r
        end

        return
    end

    function run_one_step!(model::Model)::Nothing
        for agent_x in model.agents
            agent_y = rand(filter(a -> a != agent_x, model.agents))
            set_action!(model, agent_x, agent_y)
            calc_payoff!(model, agent_x, agent_y)
            update_reputation_matrix!(model, agent_x, agent_y)
        end
    end

    population_per_reputation_logic(model::Model)::Vector{Int} = [count(agent -> agent.reputation_logic == logic, model.agents) for logic in Reputation_Logic_List]

    fitness_per_reputation_logic(model::Model)::Vector{Float64} = [sum([exp(agent.payoff) for agent in model.agents if agent.reputation_logic == logic]) for logic in Reputation_Logic_List]

    function next_logic_probabilities(model::Model, agent::Agent)::Dict{Int8, Float64}
        fitness_list = fitness_per_reputation_logic(model)
        fitness_sum = sum(fitness_list)
        population = count(a -> a.reputation_logic == agent.reputation_logic, model.agents)
        prob_dict = Dict((logic, fitness / fitness_sum * population / model.n) for (logic, fitness) in zip(Reputation_Logic_List, fitness_list) if logic != agent.reputation_logic)
        prob_dict[agent.reputation_logic] = 1 - sum(values(prob_dict))

        return prob_dict
    end

    function adaptation!(model::Model)::Nothing
        # ゲームを i 回繰り返す度に、ランダムに1つのエージェントが選ばれる。
        agent = rand(model.agents)

        if model.u > rand()
            # 確率 u で、そのエージェントはランダムに戦略を採用する (突然変異)。
            agent.reputation_logic = rand([logic for logic in Reputation_Logic_List if logic != agent.reputation_logic])
        else
            prob_dict = next_logic_probabilities(model, agent)
            next_logic = agent.reputation_logic
            prob_index = rand()
            for logic in Reputation_Logic_List
                prob_index -= prob_dict[logic]
                next_logic = logic
                prob_index < 0 && break
            end
            agent.reputation_logic = next_logic
        end

        return
    end

    function run_one_generation!(model::Model)::Nothing
        reset_agents_payoff!(model)

        for step in 1:model.steps_per_generation
            run_one_step!(model)
        end

        adaptation!(model)
    end

    function log(model::Model, generation::Int, io::IOStream)::Nothing
        agent_population = [count(a -> logic == a.reputation_logic, model.agents) for logic in Reputation_Logic_List]
        println(io, join([
            generation,
            agent_population...
        ], ","))

        if generation % 10^4 == 0
            flush(io)
            _now = format(now(), "mm/dd HH:MM:SS")
            println("$_now $(round(generation / model.generations * 100, digits=2))% ")
        end
    end

    function run!(model::Model, io::IOStream)::Nothing
        for generation in 1:model.generations
            run_one_generation!(model)
            log(model, generation, io)
        end
    end
end

# julia --threads 1 src/Simulation.jl
# julia src/Simulation.jl
if abspath(PROGRAM_FILE) == @__FILE__
    using .Simulation
    using Dates: format, now

    println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

    _now = format(now(), "yyyymmdd_HHMMSS")
    file_name = "data/$(_now).csv"
    println("file_name: $(file_name)")

    model = Simulation.Model()
    open(file_name, "w") do io
        @time Simulation.run!(model, io)
    end
end
