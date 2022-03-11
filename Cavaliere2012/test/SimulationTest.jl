module SimulationTest
    using LightGraphs
    using Statistics
    using Random
    using Test: @testset, @test, @test_throws

    include("../src/Simulation.jl")
    const sim = Simulation  # alias

    println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")

    @testset "Agent" begin
        agent = sim.Agent(3)
        @test agent.id == 3
        @test agent.pos == 3
        @test agent.is_cooperator
        @test agent.payoff == 0.0
        @test agent.effective_payoff == 0.0
    end

    @testset "Model" begin
        @testset "Constructor" begin
            model = sim.Model()
            @test model.N == 100
            @test model.k == 4
            @test model.b_c_rate == 3.0
            @test model.b == 3.0
            @test model.c == 1.0
            @test model.δ == 0.01
            @test model.u == 0.0001
            @test model.p == 0.6
            @test model.q == 0.85

            # model.agents
            for (index, agent) in enumerate(model.agents)
                @test agent.id == index
                @test agent.pos == index
                @test agent.is_cooperator
                @test agent.payoff == agent.effective_payoff == 0.0
            end

            # model.graph
            @test nv(model.graph) == 100
            @test ne(model.graph) == 200
            @test sim.mean_degree(model) == 4
        end

        @testset "reset_agents_payoff!" begin
            model = sim.Model()
            for agent in model.agents
                agent.payoff = rand()
            end

            sim.reset_agents_payoff!(model)

            for agent in model.agents
                @test agent.payoff == 0.0
            end
        end

        @testset "calc_payoff!" begin
            model = sim.Model()
            model.agents = [sim.Agent(id) for id in 1:4]
            model.graph = SimpleGraph(4)
            add_edge!(model.graph, 1, 2)
            add_edge!(model.graph, 1, 3)
            add_edge!(model.graph, 1, 4)
            add_edge!(model.graph, 2, 3)

            # If every agents are C,
            sim.calc_payoff!(model)
            @test [a.payoff for a in model.agents] == [8.0, 5.0, 5.0, 2.0]
            @test [a.effective_payoff for a in model.agents] ≈ [1.01^8, 1.01^5, 1.01^5, 1.01^2]

            # If 1 and 3 are C, 2 and 4 are D,
            sim.reset_agents_payoff!(model)
            model.agents[2].is_cooperator = false
            model.agents[4].is_cooperator = false
            sim.calc_payoff!(model)
            @test [a.payoff for a in model.agents] == [2.0, 6.0, 2.0, 3.0]
            @test [a.effective_payoff for a in model.agents] ≈ [1.01^2, 1.01^6, 1.01^2, 1.01^3]
        end

        @testset "kill_and_generate_agent!" begin
            # new_agent.pos = 32
            Random.seed!(1)
            model = sim.Model()

            sim.kill_and_generate_agent!(model)
            @test maximum([agent.id for agent in model.agents]) == 101
            @test nv(model.graph) == 100
            @test ne(model.graph) == 192
            @test neighbors(model.graph, 32) == []

            sim.kill_and_generate_agent!(model)
            @test maximum([agent.id for agent in model.agents]) == 102
            @test nv(model.graph) == 100
            @test ne(model.graph) == 187
            @test neighbors(model.graph, 4) == []
        end

        @testset "choose_role_model" begin
            model = sim.Model()
            model.agents = [sim.Agent(id) for id in 1:4]
            for (index, agent) in enumerate(model.agents)
                agent.effective_payoff = index
            end
            role_model_list = [sim.choose_role_model(model) for _ in 1:100000]
            @test mean([role_model.id == 1 for role_model in role_model_list]) ≈ 0.1 atol = 0.005
            @test mean([role_model.id == 2 for role_model in role_model_list]) ≈ 0.2 atol = 0.005
            @test mean([role_model.id == 3 for role_model in role_model_list]) ≈ 0.3 atol = 0.005
            @test mean([role_model.id == 4 for role_model in role_model_list]) ≈ 0.4 atol = 0.005
        end

        @testset "imitate_role_model!" begin
            @testset "u == 1" begin
                model = sim.Model()
                model.u = 1.0
                model.p = 0.0
                model.q = 0.0
                new_agent::sim.Agent = sim.kill_and_generate_agent!(model)
                new_agent.is_cooperator = true
                role_model::sim.Agent = sim.choose_role_model(model)
                @test neighbors(model.graph, new_agent.pos) == []
                sim.imitate_role_model!(model, new_agent, role_model)
                @test !new_agent.is_cooperator
                @test neighbors(model.graph, new_agent.pos) == []
            end
            @testset "p == 1" begin
                model = sim.Model()
                model.u = 0.0
                model.p = 1.0
                model.q = 0.0
                new_agent::sim.Agent = sim.kill_and_generate_agent!(model)
                new_agent.is_cooperator = false
                role_model::sim.Agent = sim.choose_role_model(model)
                @test neighbors(model.graph, new_agent.pos) == []
                sim.imitate_role_model!(model, new_agent, role_model)
                @test new_agent.is_cooperator
                @test neighbors(model.graph, new_agent.pos) == [role_model.pos]
            end
            @testset "q == 1" begin
                model = sim.Model()
                model.u = 0.0
                model.p = 0.0
                model.q = 1.0
                new_agent::sim.Agent = sim.kill_and_generate_agent!(model)
                new_agent.is_cooperator = false
                role_model::sim.Agent = sim.choose_role_model(model)
                @test neighbors(model.graph, new_agent.pos) == []
                sim.imitate_role_model!(model, new_agent, role_model)
                @test new_agent.is_cooperator
                @test neighbors(model.graph, new_agent.pos) == neighbors(model.graph, role_model.pos)
            end
        end

        @testset "cooperator_rate" begin
            model = sim.Model()
            @test sim.cooperator_rate(model) == 1.0

            for (index, agent) in enumerate(model.agents)
                agent.is_cooperator = index % 3 == 0
            end
            @test sim.cooperator_rate(model) == 0.33

            for (index, agent) in enumerate(model.agents)
                agent.is_cooperator = false
            end
            @test sim.cooperator_rate(model) == 0.0
        end

        @testset "mean_degree" begin
            model = sim.Model()
            @test sim.mean_degree(model) == 4
        end

        @testset "prosperity" begin
            Random.seed!(180)
            model = sim.Model()
            sim.run(model, generations = 10)
            @test sim.prosperity(model) == 0.0541
        end

        @testset "run_one_generation" begin
            # seedが1の時、new_agent.pos = 32, role_model.pos = 4
            Random.seed!(1)
            new_agent_pos = 32
            role_model_pos = 4

            model = sim.Model()
            neighbor_pos_list = deepcopy(neighbors(model.graph, role_model_pos))
            sim.run_one_generation(model)
            @test model.agents[new_agent_pos].id == 101
            @test model.agents[new_agent_pos].pos == 32
            @test model.agents[new_agent_pos].is_cooperator
            @test model.agents[new_agent_pos].payoff == 0
            @test model.agents[new_agent_pos].effective_payoff == 0

            @test neighbor_pos_list == [28, 46, 68, 99, 100]
            @test neighbors(model.graph, role_model_pos) == [28, new_agent_pos, 46, 68, 99, 100]
            @test neighbors(model.graph, new_agent_pos) == [role_model_pos, 28, 46, 68, 99, 100]
        end

        @testset "run" begin
            Random.seed!(2)
            model = sim.Model()
            sim.run(model, generations = 10)
            @test mean([agent.payoff for agent in model.agents]) == 10.8
            @test mean([agent.effective_payoff for agent in model.agents]) == 1.105436117909245
            @test nv(model.graph) == 100
            @test ne(model.graph) == 195
        end
    end
end