using Test: @testset, @test

using Agents: allagents, run!, dummystep
using DataFrames: DataFrame
using Statistics: mean
using LightGraphs: SimpleGraph, barabasi_albert, add_edge!
using GraphPlot: gplot

include("../src/agent.jl")
include("../src/model.jl")
include("../src/exec.jl")

println("Julia $VERSION")
println("Thread count: $(Threads.nthreads())")

G = barabasi_albert(10^3, 2)
println(G)
println("2 * ne(G) / nv(G) = $(2 * ne(G) / nv(G))")

@testset "agent.Player" begin
    @test Agent.Player(Agent.C) isa Agent.Player
    @test Agent.Player(1, Agent.D) isa Agent.Player
    @test Agent.Player(1, 0.5) isa Agent.Player
end

@testset "model.build_model" begin
    model = Model.build_model(G = barabasi_albert(10^3, 4), cost_model = :fixed_cost, r = 2.0, C_rate = 0.7)
    @test length(allagents(model)) == 10^3
    @test 0.65 < mean([a.strategy for a in allagents(model)]) < 0.75
end

@testset "model.model_step!" begin
    @testset "executable" begin
        G = barabasi_albert(10^3, 4)
        model = Model.build_model(G = G, r = calc_r(G, 0.8), cost_model = :fixed_cost, C_rate = 0.5)
        agent_df, model_df = run!(model, dummystep, Model.model_step!, 10; adata = [(:strategy, mean)])
        @test size(agent_df) == (11, 2)
        @test size(model_df) == (0, 0)
    end

    @testset "collect logic" begin
        # make a double-star graph
        G = SimpleGraph(16)
        [add_edge!(G, edge) for edge in [
            (1, 10),
            (1, 2), (1, 3), (1, 4), (1, 5), (1, 6), (1, 7), (1, 8), (1, 9),
            (10, 11), (10, 12), (10, 13), (10, 14), (10, 15), (10, 16)
        ]]
        model = Model.build_model(;G = G, r = 9.0, cost_model = :fixed_cost, C_rate = 1.0)
        model[1].strategy = Agent.D

        @testset "status 1" begin
            @test model[1].strategy == Agent.D
            for id in 2:10
                @test model[id].strategy == Agent.C
            end
        end

        # status 1 -> 2
        Model.model_step!(model)

        @testset "status 2" begin
            for id in 1:9
                @test model[id].strategy == Agent.D
            end
            for id in 10:16
                @test model[id].strategy == Agent.C
            end
        end

        # status 2 -> 3
        Model.model_step!(model)

        @testset "status 3" begin
            @test model[1].strategy == Agent.C
            for id in 2:9
                @test model[id].strategy == Agent.D
            end
            for id in 10:16
                @test model[id].strategy == Agent.C
            end
        end

        # status 3 -> 4
        Model.model_step!(model)

        @testset "status 4" begin
            for id in 1:16
                @test model[id].strategy == Agent.C
            end
        end
    end
end

@testset "exec.calc_r" begin
    G = barabasi_albert(10^3, 2)
    @test r = [round(calc_r(G, η), digits = 1) for η in 0.2:0.1:0.8] == [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]
end

@testset "exec.run_simulation" begin
    for cost_model in [:fixed_cost, :variable_cost]
        c_rate = run_simulation(:scale_free, cost_model, 0.7; N_gen = 10^2, N_sim = 3)
        println("[$(cost_model)] c_rate = $(c_rate)")
        @test c_rate isa Float64
    end
end
