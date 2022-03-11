module Simulation
    using LightGraphs
    using Statistics: mean
    using Dates: format, now

    mutable struct Agent
        id::Int
        pos::Int
        is_cooperator::Bool
        payoff::Float64
        effective_payoff::Float64

        Agent(id::Int) = new(id, id, true, 0.0, 0.0)
    end

    mutable struct Model
        N::Int
        k::Int
        b_c_rate::Float64
        δ::Float64
        u::Float64
        p::Float64
        q::Float64

        agents::Vector{Agent}
        graph::SimpleGraph{Int64}
        b::Float64
        c::Float64
    end

    # ノード数 N = 100 の、平均次数 k = 4 のランダムグラフ。進化過程ではノード数は一定。すべてのノードは最初同じ戦略をとる。
    function Model()::Model
        N = 100
        k = 4
        b_c_rate = 3.0
        δ = 0.01
        u = 0.0001
        p = 0.6
        q = 0.85

        agents = [Agent(id) for id in 1:N]
        graph = SimpleGraph(N, Int(N * k / 2))
        b = b_c_rate
        c = 1.0

        Model(N, k, b_c_rate, δ, u, p, q, agents, graph, b, c)
    end

    reset_agents_payoff!(model::Model) = for agent in model.agents
        agent.payoff = 0.0
    end

    function calc_payoff!(model::Model)::Nothing
        """
        Cはコストcを支払って隣接する全てのノードに利益bを与え、Dはコストを支払わず、利益も分配しない。
        各ステップ、各ノードiについて、Payoff iはその隣接ノードとのペアワイズ・インタラクションの総和として計算される。
        有効ペイオフ EPi = (1+δ)i^Payoff
        """
        for agent in filter(a -> a.is_cooperator, model.agents)
            agent.payoff -= model.c
            for neighbor_pos in neighbors(model.graph, agent.pos)
                model.agents[neighbor_pos].payoff += model.b
            end
        end

        for agent in model.agents
            agent.effective_payoff = (1.0 + model.δ)^agent.payoff
        end
    end

    function kill_and_generate_agent!(model::Model)::Agent
        # ランダムに選ばれた既存のノードがシステムから削除される。
        killed_agnet = rand(model.agents)
        deleteat!(model.agents, killed_agnet.pos)

        # 新しいノード (新規参入者) が追加される。
        new_agent_id = maximum([agent.id for agent in model.agents]) + 1
        new_agent = Agent(new_agent_id)
        new_agent.pos = killed_agnet.pos
        insert!(model.agents, killed_agnet.pos, new_agent)

        # graph
        for neighbor_pos in deepcopy(neighbors(model.graph, killed_agnet.pos))
            rem_edge!(model.graph, killed_agnet.pos, neighbor_pos)
        end

        return new_agent
    end

    function choose_role_model(model::Model)::Agent
        """
        新規参入者のロールモデルとなるノードは、母集団から確率的に選択される。
        ノード i がロールモデルとして選択される確率はその有効ペイオフ EPi に比例する。
        各ステップにおいて，ネットワークの有効ペイオフ総和は EPtot = ∑ i∈{1...N} として計算される。
        あるノードがロールモデルとして選ばれる確率はEPi / EPtotとなる。
        """
        effective_payoff_total = sum([agent.effective_payoff for agent in model.agents])
        role_model_index = effective_payoff_total * rand()
        for agent in model.agents
            role_model_index -= agent.effective_payoff
            role_model_index > 0 || return agent
        end

        throw(DomainError(role_model_index, "Something wrong..."))
    end

    function imitate_role_model!(model::Model, new_agent::Agent, role_model::Agent)::Nothing
        # 新規参入者は確率1-uでロールモデルの戦略をコピーするか，確率uで代替戦略に変異する。(u = 0.0001)
        new_agent.is_cooperator = rand() > model.u ? role_model.is_cooperator : !role_model.is_cooperator

        # 新規参入者は確率qでロールモデルの各近傍と接続する
        rand() < model.q && for neighbor_pos in neighbors(model.graph, role_model.pos)
            add_edge!(model.graph, new_agent.pos, neighbor_pos)
        end

        # 確率pでロールモデルと直接接続する
        rand() < model.p && add_edge!(model.graph, new_agent.pos, role_model.pos)

        return
    end

    cooperator_rate(model::Model)::Float64 = mean([agent.is_cooperator for agent in model.agents])

    function prosperity(model::Model)::Float64
        """
        繁栄を100-(∑i∈{1...N} Payoffi)/(N-(N-1)-(b-c)) と定義し、
        すなわち、協力者の完全連結ネットワークの総ペイオフに対するネットワークの総ペイオフの割合である。
        """
        total_payoff = sum([agent.payoff for agent in model.agents])
        max_payoff = model.N * (model.N - 1) * (model.b - model.c)
        round(total_payoff / max_payoff, digits=4)
    end

    mean_degree(model::Model)::Float64 = mean(degree(model.graph))

    function largest_component_size(model::Model)::Int
        group_size_list = [length(component) for component in connected_components(model.graph)]
        maximum(group_size_list)
    end

    function log(model::Model, generation::Int, generations::Int, io::IOStream)::Nothing
        # 長期的な協力、接続性、最大成分、繁栄は、
        # それぞれ各ステップにおける協力者数、平均ノード次数、最大成分中のノード数、繁栄の合計
        # を考慮した総ステップ数で割って算出される。
        println(io, join([
            generation,
            cooperator_rate(model),
            mean_degree(model),
            largest_component_size(model),
            prosperity(model)
        ], ","))

        if generation % 10^6 == 0
            flush(io)
            _now = format(now(), "mm/dd HH:MM:SS")
            println("$_now $(round(generation / generations * 100, digits=2))% ")
        end
    end

    function run_one_generation(model::Model)::Nothing
        reset_agents_payoff!(model)
        calc_payoff!(model)
        new_agent::Agent = kill_and_generate_agent!(model)
        role_model::Agent = choose_role_model(model)
        imitate_role_model!(model, new_agent, role_model)
    end

    function run(model::Model; generations::Int = 10^8, io = Nothing)::Nothing
        for generation in 1:generations
            run_one_generation(model)
            typeof(io) == IOStream && log(model, generation, generations, io)
        end
    end
end

# julia --threads 1 src/Simulation.jl
if abspath(PROGRAM_FILE) == @__FILE__
    using .Simulation
    using Dates: format, now

    println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

    _now = format(now(), "yyyymmdd_HHMMSS")
    file_name = "data/$(_now).csv"
    println("file_name: $(file_name)")

    model = Simulation.Model()
    open(file_name, "w") do io
        @time Simulation.run(model, generations = 10^8, io = io)
    end
end
