module Model
    using Agents: ABM, AgentBasedModel, GraphSpace, add_agent_pos!, allagents, nearby_agents, nagents
    using LightGraphs: SimpleGraph, nv
    using Statistics: mean

    include("agent.jl")

    function build_model(; G::SimpleGraph, cost_model::Symbol, r::Float64, c::Float64 = 1.0, C_rate::Float64 = 0.5)::ABM
        # "r" is the PGG enhancement factor.
        model = ABM(Agent.Player, GraphSpace(G), properties = Dict(:cost_model => cost_model, :r => r, :c => c))

        # モデル上にエージェントを配置する
        foreach(id -> add_agent_pos!(Agent.Player(id, C_rate), model), 1:nv(G))

        return model
    end

    function model_step!(model::AgentBasedModel)
        # 全部Cもしくは全部Dの場合は処理をスキップする
        average_strategy = mean([agent.strategy for agent in allagents(model)])
        (average_strategy == 0 || average_strategy == 1) && return

        calc_payoffs!(model)
        set_next_strategies!(model)
        update_strategies!(model)
    end

    function calc_payoffs!(model::AgentBasedModel)
        foreach(allagents(model)) do agent
            # The incomes of a defector and a cooperator in one group are given by P_D = c * r * n_C / (k_x + 1) and P_C = P_D - c
            # C individuals with kx neighbours contribute a cost c/(k_x + 1) per game, such that the individual contribution of each C equals c independently of the number of social ties.
            neighbors = nearby_agents(agent, model)
            k_x = length(neighbors)
            n_C = length([n for n in neighbors if n.strategy])
            _c = model.cost_model == :fixed_cost ? model.c : model.c / (k_x + 1)

            agent.payoff += _c * model.r * n_C / (k_x + 1)
            agent.strategy && (agent.payoff -= _c)
            foreach(neighbors) do neighbor
                neighbor.payoff += _c * model.r * n_C / (k_x + 1)
                neighbor.strategy && (neighbor.payoff -= _c)
            end
        end
    end

    function set_next_strategies!(model::AgentBasedModel)
        for agent in allagents(model)
            # When a site x is updated, a neighbor y is drawn at random among all kx neighbors
            neighbors::Vector{Agent.Player} = collect(nearby_agents(agent, model))
            neighbor::Agent.Player = neighbors[rand(1:end)]

#             max_payoff::Float64 = 0.0
#             for n in neighbors
#                 if n.payoff > max_payoff
#                     max_payoff = n.payoff
#                     neighbor = n
#                 end
#             end

            # only if Py > Px the strategy of chosen neighbor y replaces that of x
            # with probability given by (Py - Px) / M
            Px = agent.payoff
            Py = neighbor.payoff
            agent.next_strategy = agent.strategy
#             println("agent: $(agent.pos), $(agent.strategy), $(agent.payoff)")
#             println("neighbor: $(neighbor.pos), $(neighbor.strategy), $(neighbor.payoff)")
#             println(["$(n.pos), $(n.strategy), $(n.payoff)" for n in neighbors])

            (Py < Px) && continue
            M = max([n.payoff for n in neighbors]...) - Px
#             println("Px = $(Px), Py = $(Py), M = $(M), (Py - Px) / M = $((Py - Px) / M)")

            ((Py - Px) / M < rand()) && continue
            agent.next_strategy = neighbor.strategy
#             println("$(agent.next_strategy)\n")
        end
    end

    update_strategies!(model::AgentBasedModel) = foreach(allagents(model)) do agent
            agent.strategy = agent.next_strategy
            agent.payoff = 0f0
        end
end
