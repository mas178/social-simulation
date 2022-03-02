module SimulationTest

using Test: @testset, @test
using Random

include("../src/Simulation.jl")
const sim = Simulation  # alias

println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

@testset "Agent" begin
    @testset "constructor" begin
        agent = sim.Agent()
        @test !agent.is_cooperator
        @test agent.payoff == 0.0
        @test agent.fitness == 0.0

        agent.is_cooperator = true
        agent.payoff = 1.78
        agent.fitness = 0.178
        @test agent.is_cooperator
        @test agent.payoff == 1.78
        @test agent.fitness == 0.178
    end
end

@testset "Group" begin
    @testset "constructor" begin
        group = sim.Group(10, 1.5, 0.1)
        @test group.group_size == 10
        @test group.b == 1.5
        @test group.c == 1.0
        @test group.w == 0.1
        @test length(group.agents) == 10
        for agent in group.agents
            @test !agent.is_cooperator
            @test agent.payoff == 0.0
            @test agent.fitness == 0.0
        end
    end

    @testset "reset_payoff" begin
        group = sim.Group(9, 1.75, 0.2)
        @test all([agent.payoff == 0.0 for agent in group.agents])

        for agent in group.agents
            agent.payoff = 1.78
        end

        @test all([agent.payoff == 1.78 for agent in group.agents])

        sim.reset_payoff(group)
        @test all([agent.payoff == 0.0 for agent in group.agents])
    end

    @testset "calc_fitness" begin
        group = sim.Group(10, 2.25, 0.1)
        for agent in group.agents
            agent.payoff = 2.0
            @test agent.fitness == 0.0
        end
        sim.calc_fitness(group)
        for agent in group.agents
            @test agent.fitness == 1.1
        end
    end

    @testset "all_c and all_d" begin
        group = sim.Group(100, 9.0, 0.3)
        @test !sim.all_c(group)
        @test sim.all_d(group)

        for agent in group.agents
            agent.is_cooperator = true
        end
        @test sim.all_c(group)
        @test !sim.all_d(group)

        group.agents[1].is_cooperator = false
        @test !sim.all_c(group)
        @test !sim.all_d(group)
    end

    @testset "calc_payoff" begin
        group = sim.Group(8, 2.5, 0.2)
        group.agents[1].is_cooperator = true
        group.agents[2].is_cooperator = true
        group.agents[3].is_cooperator = false
        group.agents[4].is_cooperator = false

        # C-C
        sim.calc_payoff(group, group.agents[1], group.agents[2])
        @test group.agents[1].payoff == 1.5
        @test group.agents[2].payoff == 1.5

        # C-D
        sim.calc_payoff(group, group.agents[1], group.agents[3])
        @test group.agents[1].payoff == 0.5
        @test group.agents[3].payoff == 2.5

        # D-C
        sim.calc_payoff(group, group.agents[3], group.agents[1])
        @test group.agents[1].payoff == -0.5
        @test group.agents[3].payoff == 5.0

        # D-D
        sim.calc_payoff(group, group.agents[3], group.agents[4])
        @test group.agents[1].payoff == -0.5
        @test group.agents[2].payoff == 1.5
        @test group.agents[3].payoff == 5.0
        @test group.agents[4].payoff == 0.0
    end

    @testset "play_games" begin
        Random.seed!(123)
        group = sim.Group(10, 3.0, 0.3)
        group.agents[1].is_cooperator = true
        sim.play_games(group)
        @test [a.payoff for a in group.agents] == [-2.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 0.0, 0.0, 0.0]
    end
end

@testset "Population" begin
    @testset "constructor" begin
        population = sim.Population(10, 5, 2.5, 0.05, 0.1)
        @test population.group_count == 10
        @test population.group_size == 5
        @test population.b_c_ratio == 2.5
        @test population.w == 0.05
        @test population.q == 0.1
        @test length(population.groups) == 10

        # for each group
        @test all([g.group_size == 5 for g in population.groups])
        @test all([g.b == 2.5 for g in population.groups])
        @test all([g.c == 1.0 for g in population.groups])
        @test all([length(g.agents) == 5 for g in population.groups])

        all_agents = Iterators.flatten([group.agents for group in population.groups])
        @test sum([a.is_cooperator for a in all_agents]) == 1
    end

    @testset "all_c and all_d" begin
        population = sim.Population(5, 10, 3.5, 0.05, 0.7)
        @test !sim.all_c(population)
        @test !sim.all_d(population)

        for group in population.groups
            for agent in group.agents
                agent.is_cooperator = true
            end
        end
        @test sim.all_c(population)
        @test !sim.all_d(population)

        for group in population.groups
            for agent in group.agents
                agent.is_cooperator = false
            end
        end
        @test !sim.all_c(population)
        @test sim.all_d(population)
    end

    @testset "chose_an_agent_by_fitness" begin
        trial = 10000
        population = sim.Population(5, 6, 3.5, 0.3, 0.7)

        @testset "all fitness are 0.0" begin
            # 選んだエージェントがたまたま1つ目のエージェントである回数
            is_first_count = sum([sim.chose_an_agent_by_fitness(population) == population.groups[1].agents[1] for _ in 1:trial])

            @test is_first_count / trial ≈ 1 / 30 atol=0.005
        end

        @testset "all fitness are 1.0" begin
            for group in population.groups
                for agent in group.agents
                    agent.fitness = 1.0
                end
            end

            # 選んだエージェントがたまたま1つ目のエージェントである回数
            is_first_count = sum([sim.chose_an_agent_by_fitness(population) == population.groups[1].agents[1] for _ in 1:trial])

            @test is_first_count / trial ≈ 1 / 30 atol=0.005
        end

        @testset "all fitness are different" begin
            for (i, group) in enumerate(population.groups)
                for (j, agent) in enumerate(group.agents)
                    agent.fitness = round(((i - 1) * 6 + j - 1) / 100 + 0.01, digits=5)
                end
            end
            all_agents = Iterators.flatten([g.agents for g in population.groups])

            # 選んだエージェントがたまたま1つ目のエージェントである回数
            is_first_count = sum([sim.chose_an_agent_by_fitness(population) == population.groups[1].agents[1] for _ in 1:trial])

            @test is_first_count / trial ≈ (0.01 / ((0.01 + 0.3) * 30 / 2)) atol=0.001
        end
    end

    @testset "reproduce" begin
        population = sim.Population(5, 10, 3.5, 0.3, 0.7)
        sim.reproduce(population)
        @test sum([length(g.agents) == 10 for g in population.groups]) == 4
        @test sum([length(g.agents) == 11 for g in population.groups]) == 1
    end

    @testset "intra_group_selection" begin
        Random.seed!(0)
        population = sim.Population(5, 10, 3.5, 0.3, 0.7)
        sim.intra_group_selection(population)
        payoffs = [[agent.payoff for agent in group.agents] for group in population.groups]
        @test payoffs == [
            [-5.0, 3.5, 0.0, 3.5, 3.5, 0.0, 3.5, 0.0, 0.0, 3.5],
            [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        ]
    end

    @testset "between_group_selection" begin
        @testset "q = 1 | all group are below group_size" begin
            population = sim.Population(5, 10, 3.5, 0.3, 1.0)
            sim.between_group_selection(population)
            @test all([length(group.agents) == 10 for group in population.groups])
        end

        @testset "q = 1 | one group size > group_size" begin
            c_agent = sim.Agent()
            c_agent.is_cooperator = true

            Random.seed!(1)
            population = sim.Population(5, 10, 3.5, 0.3, 1.0)
            push!(population.groups[3].agents, c_agent)
            sim.between_group_selection(population)
            @test [length(group.agents) for group in population.groups] == [10, 10, 6, 5, 10]

            Random.seed!(2)
            population = sim.Population(5, 10, 3.5, 0.3, 1.0)
            push!(population.groups[3].agents, c_agent)
            sim.between_group_selection(population)
            @test [length(group.agents) for group in population.groups] == [10, 6, 5, 10, 10]
        end

        @testset "q = 0" begin
            population = sim.Population(5, 10, 3.5, 0.3, 0.0)

            true_agent = sim.Agent()
            true_agent.is_cooperator = true
            false_agent = sim.Agent()

            push!(population.groups[2].agents, true_agent)
            push!(population.groups[4].agents, false_agent)
            @test [length(group.agents) for group in population.groups] == [10, 11, 10, 11, 10]
            sim.between_group_selection(population)
            @test [length(group.agents) for group in population.groups] == [10, 10, 10, 10, 10]
        end
    end

    @testset "evolve" begin
        Random.seed!(0)
        population = sim.Population(5, 10, 3.5, 0.3, 0.5)
        @test !sim.evolve(population, 100)
    end
end

# @testset "run" begin
#     sim.run(generation_count = 10, trial_count = 10)
# end

end  # end of module