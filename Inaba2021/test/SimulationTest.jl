module SimulationTest
using LightGraphs
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
        @test 0.45 <= average_cooperator_rate <= 0.55
    end
end

@testset "Model" begin
    @testset "simple test" begin
        graph = cycle_graph(5)
        model = sim.Model(graph, hop_game = 2, hop_learning = 2, n_game = 4, n_learning = 4, b = 6.0)

        @test model.graph == graph
        @test model.hop_game == 2
        @test model.hop_learning == 2
        @test model.n_game == 4
        @test model.n_learning == 4
        @test model.b == 6.0
        @test model.c == 1.0
        @test model.μ == 0.0
        @test [agent.id for agent in model.agents] == [1, 2, 3, 4, 5]
    end

    @testset "neighbours' test for simple network" begin
        graph = cycle_graph(9)
        model = sim.Model(graph, hop_game = 2, hop_learning = 3, n_game = 4, n_learning = 4, b = 6.0)
        @test sort(model.neighbours_game[1]) == [2, 3, 8, 9]
        @test sort(model.neighbours_game[5]) == [3, 4, 6, 7]
        @test sort(model.neighbours_game[9]) == [1, 2, 7, 8]
        @test sort(model.neighbours_learning[1]) == [2, 3, 4, 7, 8, 9]
        @test sort(model.neighbours_learning[5]) == [2, 3, 4, 6, 7, 8]
        @test sort(model.neighbours_learning[9]) == [1, 2, 3, 6, 7, 8]

        # ホップ数がネットワークの規模を超える場合、自分以外の全てのノードが隣人として選択される
        model = sim.Model(graph, hop_game = 20, hop_learning = 20, n_game = 4, n_learning = 4, b = 6.0)
        @test sort(model.neighbours_game[1]) == [2, 3, 4, 5, 6, 7, 8, 9]
        @test sort(model.neighbours_learning[1]) == [2, 3, 4, 5, 6, 7, 8, 9]
    end

    @testset "neighbours' test for complex network" begin
        graph = barabasi_albert(100, 2)
        model = sim.Model(graph, hop_game = 1, hop_learning = 2, n_game = 4, n_learning = 4, b = 6.0)
        @test sort(model.neighbours_game[1]) == sort(filter(n_id -> n_id != 1, neighborhood(graph, 1, 1)))
        @test sort(model.neighbours_game[50]) == sort(filter(n_id -> n_id != 50, neighborhood(graph, 50, 1)))
        @test sort(model.neighbours_game[100]) == sort(filter(n_id -> n_id != 100, neighborhood(graph, 100, 1)))
        @test length(model.neighbours_game[100]) == 2  # BAモデルで最後に追加されるノードの次数はk
        @test sort(model.neighbours_learning[1]) == sort(filter(n_id -> n_id != 1, neighborhood(graph, 1, 2)))
        @test sort(model.neighbours_learning[50]) == sort(filter(n_id -> n_id != 50, neighborhood(graph, 50, 2)))
        @test sort(model.neighbours_learning[100]) == sort(filter(n_id -> n_id != 100, neighborhood(graph, 100, 2)))

        # ホップ数がネットワークの規模を超える場合、自分以外の全てのノードが隣人として選択される
        model = sim.Model(graph, hop_game = 6, hop_learning = 6, n_game = 4, n_learning = 4, b = 6.0)
        @test sort(model.neighbours_game[25]) == filter(x -> x != 25, 1:100)
        @test sort(model.neighbours_learning[75]) == filter(x -> x != 75, 1:100)
    end
end

@testset "select_neighbours" begin
    model = sim.Model(cycle_graph(5), hop_game = 2, hop_learning = 2, n_game = 2, n_learning = 10, b = 6.0)

    neighbours = sim.select_neighbours(model, model.agents[1], :game)
    @test length(neighbours) == 3
    @test model.agents[1] ∈ neighbours

    neighbours = sim.select_neighbours(model, model.agents[3], :learning)
    @test length(neighbours) == 5
    @test model.agents[3] ∈ neighbours

    @test_throws DomainError sim.select_neighbours(model, model.agents[3], :invalid)
end

@testset "calc_payoffs!" begin
    model = sim.Model(cycle_graph(5), hop_game = 2, hop_learning = 2, n_game = 4, n_learning = 2, b = 5.0)

    # 事前状態
    for agent in model.agents
        agent.is_cooperator = agent.id % 2
    end
    @test [agent.is_cooperator for agent in model.agents] == [true, false, true, false, true]
    @test [agent.payoff for agent in model.agents] == [0, 0, 0, 0, 0]

    sim.calc_payoffs!(model)

    # 事後状態
    @test [agent.payoff for agent in model.agents] == [10.0, 15.0, 10.0, 15.0, 10.0]
end

@testset "set_next_strategies!" begin
    model = sim.Model(cycle_graph(5), hop_game = 2, hop_learning = 2, n_game = 4, n_learning = 2, b = 5.0)

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
end

@testset "update_agents!" begin
    model = sim.Model(cycle_graph(5), hop_game = 2, hop_learning = 2, n_game = 4, n_learning = 4, b = 6.0)

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
        g = sim.make_graph(:scale_free, N)

        # 頂点数
        @test nv(g) == N

        # 枝数
        @test ne(g) == 1 + (N - 2) * 2

        # 平均次数
        @test 2 * ne(g) / nv(g) == 3.994

        # 平均距離 (L)
        L = mean([sum(gdistances(g, v)) / (N - 1) for v in vertices(g)])
        @test abs(L - 4.074) < 0.1

        # クラスター係数 (C)
        C = global_clustering_coefficient(g)
        @test abs(C - 0.01) < 0.0025
    end

    @testset "regular_4" begin
        N = 1000
        g = sim.make_graph(:regular_4, N)

        # 頂点数
        @test nv(g) == N

        # 枝数
        @test ne(g) == 2N

        # 全ノードの次数
        for v in vertices(g)
            @test degree(g, v) == 4
        end

        # 平均距離 (L)
        Ls = []
        for _ in 1:10
            g = sim.make_graph(:regular_4, N)
            L = mean([sum(gdistances(g, v)) / (N - 1) for v in vertices(g)])
            push!(Ls, L)
        end
        @test abs(mean(Ls) - 5.636) < 0.1
    end
end

@testset "calc_payoffs! + set_next_strategies! + update_strategies!" begin
    @testset "b = 3, oneshot" begin
        cooperator_rates = []
        for trial in 1:1000
            model = sim.Model(barabasi_albert(100, 2), hop_game = 2, hop_learning = 2, n_game = 4, n_learning = 2, b = 3.0)
            sim.calc_payoffs!(model)
            sim.set_next_strategies!(model)
            sim.update_agents!(model)
            push!(cooperator_rates, sim.cooperator_rate(model))
        end
        @test 0.358 - 0.01 <= mean(cooperator_rates) <= 0.358 + 0.01
    end

    @testset "b = 4, hop = 1, 10-loop" begin
        cooperator_rates = []
        for trial in 1:100
            model = sim.Model(barabasi_albert(1000, 2), hop_game = 1, hop_learning = 1, n_game = 4, n_learning = 4, b = 4.0)
            for step in 1:10
                sim.calc_payoffs!(model)
                sim.set_next_strategies!(model)
                sim.update_agents!(model)
            end
            push!(cooperator_rates, sim.cooperator_rate(model))
        end
        @test 0.828 - 0.1 < mean(cooperator_rates) < 0.828 + 0.1
    end

    @testset "b = 2, hop = 1, 10-loop" begin
        cooperator_rates = []
        for trial in 1:100
            model = sim.Model(barabasi_albert(1000, 2), hop_game = 1, hop_learning = 1, n_game = 4, n_learning = 4, b = 2.0)
            for step in 1:10
                sim.calc_payoffs!(model)
                sim.set_next_strategies!(model)
                sim.update_agents!(model)
            end
            push!(cooperator_rates, sim.cooperator_rate(model))
        end
        @test 0.123 - 0.1 < mean(cooperator_rates) < 0.123 + 0.1
    end
end

end
