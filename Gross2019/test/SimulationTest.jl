module SimulationTest
    using LinearAlgebra
    using Statistics: mean
    using Random
    using Test: @testset, @test, @test_throws

    include("../src/Simulation.jl")
    const sim = Simulation  # alias

    println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

    @testset "Agent" begin
        agent = sim.Agent(3)
        @test agent.id == 3
        @test agent.action == sim.D
        @test agent.reputation_logic == sim.All_D
        @test agent.payoff == 0.0

        agent.id = 1
        agent.action = sim.C
        agent.reputation_logic = sim.Heider
        agent.payoff = 9.8

        @test agent.id == 1
        @test agent.action == sim.C
        @test agent.reputation_logic == sim.Heider
        @test agent.payoff == 9.8
    end

    @testset "Model" begin
        model = sim.Model()

        @testset "Constructor" begin
            @test model.n == 100
            @test model.steps_per_generation == 10
            @test model.generations == 400000
            @test model.b == 4.0
            @test model.c == 1.0
            @test model.r == 0.3
            @test model.u == 0.01

            @test length(model.agents) == 100
            for (id, agent) in enumerate(model.agents)
                @test agent.id == id
                @test agent.action == sim.D
                @test agent.reputation_logic == sim.All_D
                @test agent.payoff == 0.0
            end

            @test model.reputation_matrix == Matrix{Float64}(I, 100, 100)
        end

        @testset "reset_agents_payoff!" begin
            [agent.payoff = 1.78 for agent in model.agents]
            sim.reset_agents_payoff!(model)
            [@test agent.payoff == 0.0 for agent in model.agents]
        end

        @testset "calc_relationship_score" begin
            model.reputation_matrix = [1.0 -1.0 1.0;
                                       1.0 1.0 0.0;
                                       0.5 0.5 1.0]
            @test sim.calc_relationship_score(model, model.agents[1], model.agents[2]) == -1
            model.agents[1].reputation_logic = sim.Heider
            @test sim.calc_relationship_score(model, model.agents[1], model.agents[2]) == -1.5
            model.agents[1].reputation_logic = sim.Friend_Focused
            @test sim.calc_relationship_score(model, model.agents[1], model.agents[2]) == -0.5
            model.agents[1].reputation_logic = 99
            @test_throws DomainError(99, "agent.reputation_logic is wrong.") sim.calc_relationship_score(model, model.agents[1], model.agents[2])
        end

        @testset "c_probability" begin
            @test sim.c_probability(-10.0) ≈ 0.00 atol = 1.0e-10
            @test sim.c_probability(-1.0) ≈ 0.007 atol = 0.001
            @test sim.c_probability(-0.5) ≈ 0.076 atol = 0.001
            @test sim.c_probability(0.0) ≈ 0.5
            @test sim.c_probability(0.5) ≈ 0.924 atol = 0.001
            @test sim.c_probability(1.0) ≈ 0.993 atol = 0.001
            @test sim.c_probability(10.0) ≈ 1.0
        end

        @testset "action" begin
            @test mean([sim.action(-0.5) == sim.C for _ in 1:10^4]) ≈ 0.076 atol = 0.01
            @test mean([sim.action(+0.0) == sim.C for _ in 1:10^4]) ≈ 0.500 atol = 0.01
            @test mean([sim.action(+0.5) == sim.C for _ in 1:10^4]) ≈ 0.924 atol = 0.01
        end

        @testset "calc_payoff!" begin
            model.agents[1].action = sim.C
            model.agents[2].action = sim.C
            sim.calc_payoff!(model, model.agents[1], model.agents[2])
            @test model.agents[1].payoff == model.b - model.c
            @test model.agents[2].payoff == model.b - model.c

            sim.reset_agents_payoff!(model)
            model.agents[1].action = sim.C
            model.agents[2].action = sim.D
            sim.calc_payoff!(model, model.agents[1], model.agents[2])
            @test model.agents[1].payoff == -model.c
            @test model.agents[2].payoff == model.b

            sim.reset_agents_payoff!(model)
            model.agents[1].action = sim.D
            model.agents[2].action = sim.C
            sim.calc_payoff!(model, model.agents[1], model.agents[2])
            @test model.agents[1].payoff == model.b
            @test model.agents[2].payoff == -model.c

            sim.reset_agents_payoff!(model)
            model.agents[1].action = sim.D
            model.agents[2].action = sim.D
            sim.calc_payoff!(model, model.agents[1], model.agents[2])
            @test model.agents[1].payoff == 0.0
            @test model.agents[2].payoff == 0.0
        end

        @testset "update_reputation_matrix!" begin
            model.reputation_matrix == [1.0 -1.0 1.0; 1.0 1.0 0.0; 0.5 0.5 1.0]
            model.agents[2].action = sim.C
            model.agents[3].action = sim.C
            sim.update_reputation_matrix!(model, model.agents[2], model.agents[3])
            @test model.reputation_matrix == [1.0 -1.0 1.0; 1.0 1.0 0.3; 0.5 0.8 1.0]

            model.agents[3].action = sim.C
            model.agents[1].action = sim.D
            sim.update_reputation_matrix!(model, model.agents[3], model.agents[1])
            @test model.reputation_matrix == [1.0 -1.0 1.0; 1.0 1.0 0.3; 0.2 0.8 1.0]

            model.agents[1].action = sim.D
            model.agents[2].action = sim.C
            sim.update_reputation_matrix!(model, model.agents[1], model.agents[2])
            @test model.reputation_matrix == [1.0 -1.0 1.0; 0.7 1.0 0.3; 0.2 0.8 1.0]

            model.agents[3].action = sim.D
            model.agents[2].action = sim.D
            sim.update_reputation_matrix!(model, model.agents[3], model.agents[2])
            @test model.reputation_matrix == [1.0 -1.0 1.0; 0.7 1.0 0.3; 0.2 0.8 1.0]
        end

        @testset "run_one_step!" begin
            Random.seed!(1)
            model = sim.Model()
            for agent in model.agents
                agent.reputation_logic = sim.Heider
            end
            sim.run_one_step!(model)
            @test [agent.payoff for agent in model.agents] == [-2.0, 4.0, 4.0, 3.0, 3.0, 6.0, -1.0, -1.0, 10.0, 3.0, 2.0, 6.0, 3.0, 4.0, 3.0, -1.0, 3.0, 3.0, 4.0, 0.0, 10.0, 0.0, 3.0, 0.0, -1.0, 2.0, 4.0, 3.0, 4.0, 3.0, 3.0, 8.0, 3.0, -1.0, 3.0, 4.0, 3.0, 4.0, 3.0, 2.0, 7.0, 3.0, -2.0, 8.0, 3.0, -1.0, 3.0, 4.0, 6.0, 7.0, 0.0, 3.0, -1.0, 3.0, 4.0, -1.0, 0.0, 3.0, 6.0, 7.0, -1.0, 5.0, 8.0, 2.0, 0.0, 2.0, 3.0, 2.0, 7.0, 2.0, 0.0, 3.0, 4.0, 7.0, 7.0, 0.0, -1.0, 6.0, -1.0, 0.0, 0.0, -1.0, 9.0, 3.0, 5.0, 3.0, 9.0, 4.0, 10.0, -1.0, -1.0, 6.0, 3.0, 3.0, 3.0, -1.0, 4.0, -1.0, 7.0, 3.0]
        end

        @testset "reproduction_probability_per_reputation_logic" begin
            for (index, agent) in enumerate(model.agents)
                if index % 2 == 0
                    agent.reputation_logic = sim.Heider
                    agent.payoff = 1.0
                elseif index % 3 == 0
                    agent.reputation_logic = sim.Friend_Focused
                    agent.payoff = 0.0
                else
                    agent.reputation_logic = sim.All_D
                    agent.payoff = -1.0
                end
            end
            @test sim.population_per_reputation_logic(model) == [50, 17, 33]
            @test sim.fitness_per_reputation_logic(model) ≈ [135.914, 17, 12.140] atol = 0.0001

            fitness_sum = sum(sim.fitness_per_reputation_logic(model))

            # All_D
            _prob_dict = sim.next_logic_probabilities(model, model.agents[1])
            @test _prob_dict[sim.Heider] ≈ 135.914 / fitness_sum * 0.33 atol = 0.0001
            @test _prob_dict[sim.Heider] ≈ 0.2717 atol = 0.0001
            @test _prob_dict[sim.Friend_Focused] ≈ 17 / fitness_sum * 0.33 atol = 0.0001
            @test _prob_dict[sim.Friend_Focused] ≈ 0.0340 atol = 0.0001
            @test _prob_dict[sim.All_D] ≈ (1 - 0.2717 - 0.0340) atol = 0.0001

            # Heider
            _prob_dict = sim.next_logic_probabilities(model, model.agents[2])
            @test _prob_dict[sim.Friend_Focused] ≈ 17 / fitness_sum * 0.5 atol = 0.0001
            @test _prob_dict[sim.Friend_Focused] ≈ 0.0515 atol = 0.0001
            @test _prob_dict[sim.All_D] ≈ 12.140 / fitness_sum * 0.5 atol = 0.0001
            @test _prob_dict[sim.All_D] ≈ 0.0368 atol = 0.0001
            @test _prob_dict[sim.Heider] ≈ (1 - 0.0515 - 0.0368) atol = 0.0001

            # Friend_Focused
            _prob_dict = sim.next_logic_probabilities(model, model.agents[3])
            @test _prob_dict[sim.Heider] ≈ 135.914 / fitness_sum * 0.17 atol = 0.0001
            @test _prob_dict[sim.Heider] ≈ 0.14 atol = 0.0001
            @test _prob_dict[sim.All_D] ≈ 12.140 / fitness_sum * 0.17 atol = 0.0001
            @test _prob_dict[sim.All_D] ≈ 0.0125 atol = 0.0001
            @test _prob_dict[sim.Friend_Focused] ≈ (1 - 0.14 - 0.0125) atol = 0.0001
        end

        @testset "adaptation!" begin
            @testset "model.u = 1.0" begin
                models = [sim.Model() for _ in 1:10^3]
                for model in models
                    model.u = 1.0
                    sim.adaptation!(model)
                end
                logic_list = [sum([a.reputation_logic for a in model.agents]) for model in models]
                @test mean(logic_list) ≈ 1.5 atol = 0.05
            end

            @testset "model.u = 0.0" begin
                Random.seed!(1)
                model = sim.Model()
                model.u = 0.0
                for agent in model.agents
                    agent.reputation_logic = rand(sim.Reputation_Logic_List)
                    agent.payoff = rand() * 2 - 1
                end
                println([agent.reputation_logic for agent in model.agents])
                sim.adaptation!(model)
                println([agent.reputation_logic for agent in model.agents])
            end
        end

        @testset "run_one_generation!" begin
            model = sim.Model()
            for (index, agent) in enumerate(model.agents)
                if index % 2 == 0
                    agent.reputation_logic = sim.Heider
                elseif index % 3 == 0
                    agent.reputation_logic = sim.Friend_Focused
                else
                    agent.reputation_logic = sim.All_D
                end
            end
            sim.run_one_generation!(model)
        end
    end
end