#=
SimulationTest:
- Julia version:
- Author: inaba
- Date: 2021-11-20
=#
module SimulationTest
using Test
using LightGraphs
using Statistics: mean

include("../src/Simulation.jl")
const sim = Simulation  # alias

@testset "Agent" begin
    @testset "Deterministic test" begin
        agent = sim.Agent(1)
        @test agent.id == 1
        @test agent.next_is_cooperator == false
        @test agent.next_is_punisher == false
        @test agent.payoff == 0.0
    end

    # is_cooperator と is_punisher が50%程度の確率で設定されていることを確認。
    @testset "Probabilistic test" begin
        agents = [sim.Agent(id) for id in 1:1000]
        average_cooperator_rate = mean([agent.is_cooperator for agent in agents])
        average_punisher_rate = mean([agent.is_punisher for agent in agents])
        @test 0.45 <= average_cooperator_rate <= 0.55
        @test 0.45 <= average_punisher_rate <= 0.55
    end
end

@testset "Model" begin
    @testset "neighbours" begin
        agents = [sim.Agent(id) for id in 1:5]
        graph = cycle_graph(length(agents))
        model = sim.Model(agents, graph, g = 0.0, p = 1.0, a = 0.0)
        # 1の隣人は 4, 5, 2, 3 であることを確認
        @test sort(model.neighbours[1]) == sort([4, 5, 2, 3])
        # 2の隣人は 5, 1, 3, 4 であることを確認
        @test sort(model.neighbours[2]) == sort([5, 1, 3, 4])
        # 3の隣人は 1, 2, 4, 5 であることを確認
        @test sort(model.neighbours[3]) == sort([1, 2, 4, 5])
        # 4の隣人は 2, 3, 5, 1 であることを確認
        @test sort(model.neighbours[4]) == sort([2, 3, 5, 1])
        # 5の隣人は 3, 4, 1, 2 であることを確認
        @test sort(model.neighbours[5]) == sort([3, 4, 1, 2])
    end

    @testset "calc_payoffs!" begin
        agents = [sim.Agent(id) for id in 1:10]

        # agentの戦略を固定する。(戦略を確率論的にではなく決定論的に決めるのが目的なので、どの戦略にするかは恣意的に決めて良い)
        for agent in agents
            agent.is_cooperator = (agent.id % 3 == 2)
            agent.is_punisher = (agent.id % 3 == 1)
        end

        graph = cycle_graph(length(agents))
        model = sim.Model(agents, graph, g = 0.0, p = 1.0, a = 0.0)
        sim.calc_payoffs!(model)
    end
end
end
