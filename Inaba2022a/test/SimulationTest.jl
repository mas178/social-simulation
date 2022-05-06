module SimulationTest
using Graphs
using Statistics: mean
using Test: @testset, @test, @test_throws

include("../src/Simulation.jl")
const sim = Simulation  # alias

println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

@testset "Agent" begin
    @testset "Deterministic test" begin
        agent = sim.Agent(1)
        @test agent.id == 1
        @test agent.next_is_cooperator == false
        @test agent.payoff == 0.0
    end

    # is_cooperatorが50%程度の確率で設定されていることを確認。
    @testset "Probabilistic test" begin
        agents = [sim.Agent(id) for id in 1:1000]
        average_cooperator_rate = mean([agent.is_cooperator for agent in agents])
        @test average_cooperator_rate ≈ 0.5 atol = 0.1
    end
end

@testset "Model" begin
    @testset "simple test" begin
        graph = cycle_graph(5)
        model = sim.Model(graph, hop_game = 2, hop_learning = 2, b = 6.0, μ = 0.0, δ = 1.0)

        @test model.graph == graph
        @test model.hop_game == 2
        @test model.hop_learning == 2
        @test model.b == 6.0
        @test model.c == 1.0
        @test model.μ == 0.0
        @test [agent.id for agent in model.agents] == [1, 2, 3, 4, 5]
    end

    @testset "neighbours' test for simple network" begin
        graph = cycle_graph(9)
        model = sim.Model(graph, hop_game = 2, hop_learning = 3, b = 6.0, μ = 0.0, δ = 1.0)
        @test sort([agent.id for agent in model.neighbours_game[1]]) == [1, 2, 3, 8, 9]
        @test sort([agent.id for agent in model.neighbours_game[5]]) == [3, 4, 5, 6, 7]
        @test sort([agent.id for agent in model.neighbours_game[9]]) == [1, 2, 7, 8, 9]
        @test sort([agent.id for agent in model.neighbours_learning[1]]) == [1, 2, 3, 4, 7, 8, 9]
        @test sort([agent.id for agent in model.neighbours_learning[5]]) == [2, 3, 4, 5, 6, 7, 8]
        @test sort([agent.id for agent in model.neighbours_learning[9]]) == [1, 2, 3, 6, 7, 8, 9]

        # ホップ数がネットワークの規模を超える場合、全てのノードが隣人として選択される
        model = sim.Model(graph, hop_game = 20, hop_learning = 20, b = 6.0, μ = 0.0, δ = 1.0)
        @test sort([agent.id for agent in model.neighbours_game[1]]) == [1, 2, 3, 4, 5, 6, 7, 8, 9]
        @test sort([agent.id for agent in model.neighbours_learning[1]]) == [1, 2, 3, 4, 5, 6, 7, 8, 9]
    end

    @testset "neighbours' test for complex network" begin
        graph = barabasi_albert(100, 2)
        model = sim.Model(graph, hop_game = 1, hop_learning = 2, b = 6.0, μ = 0.0, δ = 1.0)
        @test sort([agent.id for agent in model.neighbours_game[1]]) == sort(neighborhood(graph, 1, 1))
        @test sort([agent.id for agent in model.neighbours_game[50]]) == sort(neighborhood(graph, 50, 1))
        @test sort([agent.id for agent in model.neighbours_game[100]]) == sort(neighborhood(graph, 100, 1))
        model.neighbours_game[100]
        @test length(model.neighbours_game[100]) == 3  # BAモデルで最後に追加されるノードの次数はk
        @test sort([agent.id for agent in model.neighbours_learning[1]]) == sort(neighborhood(graph, 1, 2))
        @test sort([agent.id for agent in model.neighbours_learning[50]]) == sort(neighborhood(graph, 50, 2))
        @test sort([agent.id for agent in model.neighbours_learning[100]]) == sort(neighborhood(graph, 100, 2))

        # ホップ数がネットワークの規模を超える場合、全てのノードが隣人として選択される
        model = sim.Model(graph, hop_game = 6, hop_learning = 6, b = 6.0, μ = 0.0, δ = 1.0)
        @test sort([agent.id for agent in model.neighbours_game[25]]) == 1:100
        @test sort([agent.id for agent in model.neighbours_learning[75]]) == 1:100
    end
end

@testset "calc_payoffs!" begin
    g = SimpleGraph(5)
    add_edge!(g, 1, 2)
    add_edge!(g, 2, 3)
    add_edge!(g, 3, 1)
    add_edge!(g, 2, 4)
    add_edge!(g, 3, 5)
    model = sim.Model(g, hop_game = 1, hop_learning = 2, b = 5.0, μ = 0.0, δ = 1.0)

    @testset "calc_pattern == 1" begin
        model = sim.Model(g, hop_game = 1, hop_learning = 2, b = 5.0, μ = 0.0, δ = 1.0)

        # 事前状態
        for agent in model.agents
            agent.is_cooperator = agent.id % 2
        end
        @test [agent.is_cooperator for agent in model.agents] == [true, false, true, false, true]
        @test [agent.payoff for agent in model.agents] == [0, 0, 0, 0, 0]
    
        sim.calc_payoffs!(model)
    
        # 事後状態
        @test [agent.payoff for agent in model.agents] ≈ [6.5833, 9.5833, 10.5833, 2.5, 6.75] atol = 10^-4
    end
    @testset "calc_pattern == 2" begin
        model = sim.Model(g, hop_game = 1, hop_learning = 2, b = 5.0, μ = 0.0, δ = 1.0)

        # 事前状態
        for agent in model.agents
            agent.is_cooperator = agent.id % 2
        end
        @test [agent.is_cooperator for agent in model.agents] == [true, false, true, false, true]
        @test [agent.payoff for agent in model.agents] == [0, 0, 0, 0, 0]
    
        sim.calc_payoffs!(model, calc_pattern = 2)
    
        # 事後状態
        @test [agent.payoff for agent in model.agents] ≈ [2.1944, 2.3958, 2.6458, 1.25, 3.375] atol = 10^-4
    end
    @testset "calc_pattern == 3" begin
        model = sim.Model(g, hop_game = 1, hop_learning = 2, b = 5.0, μ = 0.0, δ = 1.0)

        # 事前状態
        for agent in model.agents
            agent.is_cooperator = agent.id % 2
        end
        @test [agent.is_cooperator for agent in model.agents] == [true, false, true, false, true]
        @test [agent.payoff for agent in model.agents] == [0, 0, 0, 0, 0]
    
        sim.calc_payoffs!(model, calc_pattern = 2)
    
        # 事後状態
        @test [agent.payoff for agent in model.agents] ≈ [2.1944, 2.3958, 2.6458, 1.25, 3.375] atol = 10^-4
    end
end

@testset "role_model and payoff_to_fitness" begin
    model = sim.Model(cycle_graph(5), hop_game=2, hop_learning=2, b=6.0, μ=0.0, δ = 0.1)
    [agent.payoff = i for (i, agent) in enumerate(model.agents)]

    counters = [0, 0, 0, 0, 0]
    trial = 10^4
    fitness_vec = [sim.payoff_to_fitness(a.payoff, 0.1) for a in model.agents]
    @test fitness_vec == [1.0, 1.1, 1.2, 1.3, 1.4]

    for _ in 1:trial
        counters[sim.role_model(model, model.agents[1], true).id] += 1
    end

    @test counters / trial ≈ fitness_vec / sum(fitness_vec) atol = 0.1
end

@testset "set_next_strategies!" begin
    model = sim.Model(cycle_graph(5), hop_game = 2, hop_learning = 2, b = 5.0, μ = 0.0, δ = 0.1)

    @testset "If the collaborators have a high payoff, the next generation will all be collaborators." begin
        # 事前状態
        for agent in model.agents
            agent.is_cooperator = agent.id % 2
            agent.payoff = agent.id % 2
        end
        @test [agent.is_cooperator for agent in model.agents] == [true, false, true, false, true]
        @test [agent.payoff for agent in model.agents] == [1, 0, 1, 0, 1]

        sim.set_next_strategies!(model)

        # 事後状態
        @test [agent.next_is_cooperator for agent in model.agents] == [true, true, true, true, true]
    end

    @testset "If the defectors have a high payoff, the next generation will all be defectors." begin
        # 事前状態
        for agent in model.agents
            agent.is_cooperator = (agent.id + 1) % 2
            agent.payoff = agent.id % 2
        end
        @test [agent.is_cooperator for agent in model.agents] == [false, true, false, true, false]
        @test [agent.payoff for agent in model.agents] == [1, 0, 1, 0, 1]

        sim.set_next_strategies!(model)

        # 事後状態
        @test [agent.next_is_cooperator for agent in model.agents] == [false, false, false, false, false]
    end

    @testset "Weak Selection" begin
        counters = [0, 0, 0, 0, 0]
        trial = 10^4

        for _ in 1:trial
            model = sim.Model(cycle_graph(5), hop_game=2, hop_learning=2, b=6.0, μ=0.0, δ = 0.1)
            [agent.payoff = i for (i, agent) in enumerate(model.agents)]
            [agent.is_cooperator = (i ∈ [1, 2]) for (i, agent) in enumerate(model.agents)]

            sim.set_next_strategies!(model, weak_selection=true)
            counters += [a.next_is_cooperator for a in model.agents]
        end
        @test counters / trial ≈ [0.35, 0.35, 0.35, 0.35, 0.35] atol = 0.025
    end
end

@testset "update_agents!" begin
    model = sim.Model(cycle_graph(5), hop_game = 2, hop_learning = 2, b = 6.0, μ = 0.0, δ = 1.0)

    # 事前状態
    for agent in model.agents
        agent.is_cooperator = false
        agent.next_is_cooperator = agent.id % 2
        agent.payoff = 123.5
    end

    sim.update_agents!(model)

    # 事後状態
    for agent in model.agents
        @test agent.is_cooperator == agent.id % 2
        @test agent.payoff == 0.0
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

@testset "calc_payoffs! + set_next_strategies! + update_strategies!" begin
    @testset "b = 3, oneshot" begin
        cooperator_rates = []
        for trial in 1:1000
            model = sim.Model(barabasi_albert(100, 2), hop_game = 2, hop_learning = 2, b = 3.0, μ = 0.0, δ = 1.0)
            sim.calc_payoffs!(model)
            sim.set_next_strategies!(model)
            sim.update_agents!(model)
            push!(cooperator_rates, sim.cooperator_rate(model))
        end
        @test mean(cooperator_rates) ≈ 0.358 atol = 0.01
    end

    @testset "b = 4, hop = 1, 10-loop" begin
        cooperator_rates = []
        for trial in 1:100
            model = sim.Model(barabasi_albert(1000, 2), hop_game = 1, hop_learning = 1, b = 4.0, μ = 0.0, δ = 1.0)
            for step in 1:10
                sim.calc_payoffs!(model)
                sim.set_next_strategies!(model)
                sim.update_agents!(model)
            end
            push!(cooperator_rates, sim.cooperator_rate(model))
        end
        @test mean(cooperator_rates) ≈ 0.828 atol = 0.01
    end

    @testset "b = 2, hop = 1, 10-loop" begin
        cooperator_rates = []
        for trial in 1:100
            model = sim.Model(barabasi_albert(1000, 2), hop_game = 1, hop_learning = 1, b = 2.0, μ = 0.0, δ = 1.0)
            for step in 1:10
                sim.calc_payoffs!(model)
                sim.set_next_strategies!(model)
                sim.update_agents!(model)
            end
            push!(cooperator_rates, sim.cooperator_rate(model))
        end
        @test mean(cooperator_rates) ≈ 0.123 atol = 0.01
    end
end

end
