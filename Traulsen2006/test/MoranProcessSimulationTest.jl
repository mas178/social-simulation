module MoranProcessSimulationTest

using Test: @testset, @test

include("../src/MoranProcessSimulation.jl")
const sim = MoranProcessSimulation  # alias
const trial = 10000

println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

@testset "Population" begin
    @testset "constructor" begin
        population = sim.Population(10, 1)
        @test population.N == 10
        @test population.i == 1
        @test length(population.agents) == 10
        @test population.agents[1]
        for i in 2:10
            @test !population.agents[i]
        end
    end

    @testset "all_ture and all_false" begin
        population = sim.Population(10, 2)
        @test !sim.all_true(population)
        @test !sim.all_false(population)

        for j = 1:2
            population.agents[j] = false
        end
        @test !sim.all_true(population)
        @test sim.all_false(population)

        for j = 1:10
            population.agents[j] = true
        end
        @test sim.all_true(population)
        @test !sim.all_false(population)
    end

    @testset "one_generation" begin
        populations = [sim.Population(10, 1) for _ in 1:trial]
        [sim.one_generation(p) for p in populations]
        result = [sum(p.agents) for p in populations]
        @test length([x for x in result if x == 2]) / trial ≈ 0.09 atol=0.01
        @test length([x for x in result if x == 1]) / trial ≈ 0.82 atol=0.01
        @test length([x for x in result if x == 0]) / trial ≈ 0.09 atol=0.01

        populations = [sim.Population(10, 2) for _ in 1:trial]
        [sim.one_generation(p) for p in populations]
        result = [sum(p.agents) for p in populations]
        @test length([x for x in result if x == 3]) / trial ≈ 0.16 atol=0.01
        @test length([x for x in result if x == 2]) / trial ≈ 0.68 atol=0.01
        @test length([x for x in result if x == 1]) / trial ≈ 0.16 atol=0.01
    end

    @testset "evolve" begin
        populations = [sim.Population(10, 1) for _ in 1:trial]
        [sim.evolve(p) for p in populations]
        @test sum([sim.all_true(p) for p in populations]) / trial ≈ 0.1 atol=0.01

        populations = [sim.Population(10, 7) for _ in 1:trial]
        [sim.evolve(p) for p in populations]
        @test sum([sim.all_true(p) for p in populations]) / trial ≈ 0.7 atol=0.01
    end
end
end  # end of module