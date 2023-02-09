module SimulationTest
using Graphs
using Statistics: mean
using Random
using Test: @testset, @test, @test_throws

include("../src/Simulation.jl")
const sim = Simulation  # alias

println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

@testset "Agent" begin
    @testset "Deterministic test" begin
        agent = sim.Agent(1)
        @test agent.id == 1
        @test agent.next_strategy == sim.D
        @test agent.payoff == 0.0
        @test agent.fitness == 0.0
    end

    # is_cooperatorが50%程度の確率で設定されていることを確認。
    @testset "Probabilistic test" begin
        agents = [sim.Agent(id) for id in 1:1000]
        average_cooperator_rate = mean([agent.strategy == sim.C for agent in agents])
        @test average_cooperator_rate ≈ 0.5 atol = 0.1
    end
end

@testset "Model" begin
    @testset "simple test" begin
        graph = cycle_graph(5)
        model = sim.Model(graph, hop_game = 2, hop_learning = 2, b = 6.0, μ = 0.0, δ = 1.0, interaction_rule=sim.PairWise, update_rule=sim.DB)

        @test model.graph == graph
        @test model.hop_game == 2
        @test model.hop_learning == 2
        @test model.b == 6.0
        @test model.c == 1.0
        @test model.μ == 0.0
        @test model.interaction_rule == sim.PairWise
        @test model.update_rule == sim.DB
        @test [agent.id for agent in model.agents] == [1, 2, 3, 4, 5]
    end

    @testset "neighbours' test for simple network" begin
        graph = cycle_graph(9)
        model = sim.Model(graph, hop_game = 2, hop_learning = 3, b = 6.0, μ = 0.0, δ = 1.0, interaction_rule=sim.PairWise, update_rule=sim.DB)
        @test sort([agent.id for agent in model.neighbours_game[1]]) == [2, 3, 8, 9]
        @test sort([agent.id for agent in model.neighbours_game[5]]) == [3, 4, 6, 7]
        @test sort([agent.id for agent in model.neighbours_game[9]]) == [1, 2, 7, 8]
        @test sort([agent.id for agent in model.neighbours_learning[1]]) == [2, 3, 4, 7, 8, 9]
        @test sort([agent.id for agent in model.neighbours_learning[5]]) == [2, 3, 4, 6, 7, 8]
        @test sort([agent.id for agent in model.neighbours_learning[9]]) == [1, 2, 3, 6, 7, 8]

        # ホップ数がネットワークの規模を超える場合、全てのノードが隣人として選択される
        model = sim.Model(graph, hop_game = 20, hop_learning = 20, b = 6.0, μ = 0.0, δ = 1.0, interaction_rule=sim.PairWise, update_rule=sim.DB)
        @test sort([agent.id for agent in model.neighbours_game[1]]) == [2, 3, 4, 5, 6, 7, 8, 9]
        @test sort([agent.id for agent in model.neighbours_learning[1]]) == [2, 3, 4, 5, 6, 7, 8, 9]
    end

    @testset "neighbours' test for complex network" begin
        graph = barabasi_albert(100, 2)
        model = sim.Model(graph, hop_game = 1, hop_learning = 2, b = 6.0, μ = 0.0, δ = 1.0, interaction_rule=sim.PairWise, update_rule=sim.DB)
        @test sort([agent.id for agent in model.neighbours_game[1]]) == [_id for _id in sort(neighborhood(graph, 1, 1)) if _id != 1]
        @test sort([agent.id for agent in model.neighbours_game[50]]) == [_id for _id in sort(neighborhood(graph, 50, 1)) if _id != 50]
        @test sort([agent.id for agent in model.neighbours_game[100]]) == [_id for _id in sort(neighborhood(graph, 100, 1)) if _id != 100]
        model.neighbours_game[100]
        @test length(model.neighbours_game[100]) == 2  # BAモデルで最後に追加されるノードの次数はk
        @test sort([agent.id for agent in model.neighbours_learning[1]]) == [_id for _id in sort(neighborhood(graph, 1, 2)) if _id != 1]
        @test sort([agent.id for agent in model.neighbours_learning[50]]) == [_id for _id in sort(neighborhood(graph, 50, 2)) if _id != 50]
        @test sort([agent.id for agent in model.neighbours_learning[100]]) == [_id for _id in sort(neighborhood(graph, 100, 2)) if _id != 100]

        # ホップ数がネットワークの規模を超える場合、全てのノードが隣人として選択される
        model = sim.Model(graph, hop_game = 6, hop_learning = 6, b = 6.0, μ = 0.0, δ = 1.0, interaction_rule=sim.PairWise, update_rule=sim.DB)
        @test sort([agent.id for agent in model.neighbours_game[25]]) == [_id for _id in 1:100 if _id != 25]
        @test sort([agent.id for agent in model.neighbours_learning[75]]) == [_id for _id in 1:100 if _id != 75]
    end
end

@testset "cooperator_rate" begin
    graph = barabasi_albert(10^3, 2)
    model = sim.Model(graph, hop_game = 6, hop_learning = 6, b = 6.0, μ = 0.0, δ = 1.0, interaction_rule=sim.PairWise, update_rule=sim.DB)
    for agent in model.agents
        agent.strategy = (agent.id % 5 == 0 ? sim.C : sim.D)
    end
    @test sim.cooperator_rate(model) == 0.2
end

@testset "calc_payoffs!" begin
    g = SimpleGraph(5)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    add_edge!(g, 3, 1)
    add_edge!(g, 2, 4)
    add_edge!(g, 3, 5)
    model = sim.Model(g, hop_game = 1, hop_learning = 2, b = 5.0, μ = 0.0, δ = 1.0, interaction_rule=sim.PairWise, update_rule=sim.DB)

    @testset "interaction_rule == PairWise" begin
        # 事前状態
        model.interaction_rule = sim.PairWise
        for agent in model.agents
            agent.strategy = agent.id % 2 == 1 ? sim.C : sim.D
            agent.payoff = 0.0
        end
    
        sim.calc_payoffs!(model)
    
        # 事後状態
        @test [agent.payoff for agent in model.agents] == [0.9999, 2.4, 1.9999, 0.0, 1.0]
    end
    @testset "interaction_rule == Group" begin
        # 事前状態
        model.interaction_rule = sim.Group
        for agent in model.agents
            agent.strategy = agent.id % 2 == 1 ? sim.C : sim.D
            agent.payoff = 0.0
        end
    
        sim.calc_payoffs!(model)
    
        # 事後状態
        @test [agent.payoff for agent in model.agents] ≈ [6.5833, 9.5833, 10.5833, 2.5, 6.75] atol = 10^-4
    end
end

@testset "update_fitness!" begin
    graph = barabasi_albert(10, 2)
    model = sim.Model(graph, hop_game = 6, hop_learning = 6, b = 6.0, μ = 0.0, δ = 1.0, interaction_rule=sim.PairWise, update_rule=sim.DB)
    [agent.payoff = agent.id for agent in model.agents]

    model.δ = 1.0
    sim.update_fitness!(model)
    @test [agent.fitness for agent in model.agents] == [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]

    model.δ = 0.1
    sim.update_fitness!(model)
    @test [agent.fitness for agent in model.agents] ≈ [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9]
end

@testset "update_strategies!" begin
    model = sim.Model(cycle_graph(5), hop_game = 2, hop_learning = 2, b = 5.0, μ = 0.0, δ = 0.1, interaction_rule=sim.PairWise, update_rule=sim.DB)

    @testset "BD" begin
        # 事前状態
        Random.seed!(1)
        model.update_rule = sim.BD
        for agent in model.agents
            agent.strategy = agent.id % 2 == 1 ? sim.C : sim.D
            agent.fitness = agent.id % 2
        end
        @test [agent.strategy for agent in model.agents] == [sim.C, sim.D, sim.C, sim.D, sim.C]
        @test [agent.fitness for agent in model.agents] == [1, 0, 1, 0, 1]

        sim.update_strategies!(model)

        # 事後状態
        @test [agent.next_strategy for agent in model.agents] == [sim.D, sim.D, sim.D, sim.D, sim.C]
    end

    @testset "DB" begin
        # 事前状態
        Random.seed!(1)
        model.update_rule = sim.DB
        for agent in model.agents
            agent.strategy = agent.id % 2 == 1 ? sim.C : sim.D
            agent.fitness = agent.id % 2
        end
        @test [agent.strategy for agent in model.agents] == [sim.C, sim.D, sim.C, sim.D, sim.C]
        @test [agent.fitness for agent in model.agents] == [1, 0, 1, 0, 1]

        sim.update_strategies!(model)

        # 事後状態
        @test [agent.next_strategy for agent in model.agents] == [sim.C, sim.C, sim.C, sim.C, sim.C]
    end

    @testset "IM" begin
        # 事前状態
        Random.seed!(1)
        model.update_rule = sim.IM
        for agent in model.agents
            agent.strategy = agent.id % 2 == 1 ? sim.C : sim.D
            agent.payoff = agent.id % 2
        end
        @test [agent.strategy for agent in model.agents] == [sim.C, sim.D, sim.C, sim.D, sim.C]
        @test [agent.payoff for agent in model.agents] == [1, 0, 1, 0, 1]

        sim.update_strategies!(model)

        # 事後状態
        @test [agent.next_strategy for agent in model.agents] == [sim.C, sim.C, sim.C, sim.C, sim.C]
    end
end

@testset "update_agents!" begin
    model = sim.Model(cycle_graph(5), hop_game = 2, hop_learning = 2, b = 6.0, μ = 0.0, δ = 1.0, interaction_rule=sim.PairWise, update_rule=sim.DB)

    # 事前状態
    for agent in model.agents
        agent.strategy = sim.D
        agent.next_strategy = (agent.id % 2 == 1 ? sim.C : sim.D)
        agent.payoff = 123.5
        agent.fitness = 123.5
    end

    sim.update_agents!(model)

    # 事後状態
    for agent in model.agents
        @test agent.strategy == (agent.id % 2 == 1 ? sim.C : sim.D)
        @test agent.next_strategy == (agent.id % 2 == 1 ? sim.C : sim.D)
        @test agent.payoff == 0.0
        @test agent.fitness == 0.0
    end
end

@testset "make_graph" begin
    @testset "scale_free" begin
        N = 1000
        g = sim.make_graph(:scale_free_4, N)

        # 連結
        @test is_connected(g)

        # 頂点数
        @test nv(g) == N

        # 枝数
        @test ne(g) == 1 + (N - 2) * 2

        # 平均次数
        @test mean(degree(g)) == 3.994

        # 平均距離 (L)
        L = mean([sum(gdistances(g, v)) / N for v in vertices(g)])
        @test L ≈ 4.0 atol = 0.2

        # クラスター係数 (C)
        C = global_clustering_coefficient(g)
        @test C ≈ 0.01 atol = 0.005
    end

    @testset "regular_4" begin
        N = 1000
        g = sim.make_graph(:regular_4, N)

        # 連結
        @test is_connected(g)

        # 頂点数
        @test nv(g) == 1024

        # 枝数
        @test ne(g) == 2 * 1024

        # 全ノードの次数
        for v in vertices(g)
            @test degree(g, v) == 4
        end

        # 平均距離 (L)
        @test mean([sum(gdistances(g, v)) / N for v in vertices(g)]) ≈ 16.384

        # クラスター係数 (C)
        @test global_clustering_coefficient(g) == 0
    end

    @testset "random_4" begin
        N = 1000
        g = sim.make_graph(:random_4, N)

        # 連結
        @test is_connected(g)

        # 頂点数
        @test nv(g) == N

        # 枝数
        @test ne(g) == 2N

        # 平均次数
        @test mean(degree(g)) == 4

        # 平均距離 (L)
        gs = [sim.make_graph(:random_4, N) for _ in 1:10]
        Ls = [mean([mean(gdistances(_g, v)) for v in vertices(_g)]) for _g in gs]
        @test mean(Ls) ≈ log(N) / log(4) atol = 0.5

        # クラスター係数 (C)
        C = global_clustering_coefficient(g)
        @test C ≈ 4 / N atol = 0.005
    end
end
@testset "degree_check" begin
    N = 1000
    graph = sim.make_graph(:scale_free_4, N)

    file_name = "data/degrees.csv"
    open(file_name, "w") do io
        for hop_learning in 1:10
            model = sim.Model(graph, hop_game = 1, hop_learning = hop_learning, b = 6.0, μ = 0.0, δ = 1.0, interaction_rule=sim.PairWise, update_rule=sim.DB)
            degrees = [length(nodes) for nodes in model.neighbours_learning]
            for degree in degrees
                println(io, join([hop_learning, degree], ","))
            end
        end    
    end
end
end
