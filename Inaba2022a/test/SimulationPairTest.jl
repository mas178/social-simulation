module SimulationPairTest
using Graphs
using Statistics: mean
using Random
using Test: @testset, @test, @test_throws

include("../src/SimulationPair.jl")
const sim = Simulation  # alias

println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

# julia test/SimulationPairTest.jl

@testset "Agent" begin
    @testset "Deterministic test" begin
        agent = sim.Agent(1)
        @test agent.id == 1
        @test agent.next_strategy == sim.D
        @test agent.payoff == 0.0
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
        model = sim.Model(graph, 6.0)

        @test model.graph == graph
        @test model.b == 6.0
        @test [agent.id for agent in model.agents] == [1, 2, 3, 4, 5]
    end
end

@testset "cooperator_rate" begin
    graph = barabasi_albert(10^3, 2)
    model = sim.Model(graph, 6.0)
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
    model = sim.Model(g, 5.0)
    Random.seed!(1)

    # 事前状態
    for agent in model.agents
        agent.strategy = agent.id % 2 == 1 ? sim.C : sim.D
        agent.payoff = 0.0
    end

    sim.calc_payoffs!(model)

    # 事後状態
    @test [agent.payoff for agent in model.agents] == [0.0, 5.0, 1.0, 0.00001, 1.0]
end

@testset "update_strategies!" begin
    Random.seed!(5)
    model = sim.Model(cycle_graph(3), 5.0)

    # 事前状態
    model.agents[1].payoff = 10.0
    model.agents[2].payoff = 1.0
    model.agents[3].payoff = 1.0
    model.agents[1].strategy = sim.C
    model.agents[2].strategy = sim.D
    model.agents[3].strategy = sim.D

    sim.update_strategies!(model)

    # 事後状態
    @test [agent.next_strategy for agent in model.agents] == [sim.C, sim.C, sim.C]
end

@testset "update_agents!" begin
    model = sim.Model(cycle_graph(5), 6.0)

    # 事前状態
    for agent in model.agents
        agent.strategy = sim.D
        agent.next_strategy = (agent.id % 2 == 1 ? sim.C : sim.D)
        agent.payoff = 123.5
    end

    sim.update_agents!(model)

    # 事後状態
    for agent in model.agents
        @test agent.strategy == (agent.id % 2 == 1 ? sim.C : sim.D)
        @test agent.next_strategy == (agent.id % 2 == 1 ? sim.C : sim.D)
        @test agent.payoff == 0.0
    end
end

@testset "pairwise_fermi" begin
    @test sim.pairwise_fermi(2.0, 1.0) ≈ 0.0 atol = 10^-4
    @test sim.pairwise_fermi(2.2, 2.0) ≈ 0.1192 atol = 10^-4
    @test sim.pairwise_fermi(1.1, 1.0) ≈ 0.2689 atol = 10^-4
    @test sim.pairwise_fermi(1.0, 1.0) ≈ 0.5
    @test sim.pairwise_fermi(1.0, 1.1) ≈ 0.7311 atol = 10^-4
    @test sim.pairwise_fermi(1.0, 2.0) ≈ 1.0 atol = 10^-4
end
end
