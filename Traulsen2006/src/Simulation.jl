module Simulation

using Dates: format, now
using Random

mutable struct Agent
    is_cooperator::Bool
    payoff::Float64
    fitness::Float64

    Agent() = new(false, 0.0, 0.0)
end

mutable struct Group
    group_size::Int
    b::Float64
    c::Float64
    w::Float64
    agents::Vector{Agent}

    Group(group_size::Int, b_c_ratio::Float64, w::Float64) = new(
        group_size,
        b_c_ratio,
        1.0,
        w,
        [Agent() for _ in 1:group_size]
    )
end

reset_payoff(group::Group)::Nothing = for agent in group.agents
    agent.payoff = 0.0
end

calc_fitness(group::Group)::Nothing = for agent in group.agents
    agent.fitness = round(1 - group.w + group.w * agent.payoff, digits = 5)
end

all_c(group::Group)::Bool = all([a.is_cooperator for a in group.agents])

all_d(group::Group)::Bool = all([!a.is_cooperator for a in group.agents])

function calc_payoff(group::Group, agent::Agent, opponent::Agent)::Nothing
    if agent.is_cooperator && opponent.is_cooperator
        agent.payoff += group.b - group.c
        opponent.payoff += group.b - group.c
    elseif agent.is_cooperator && !opponent.is_cooperator
        agent.payoff -= group.c
        opponent.payoff += group.b
    elseif !agent.is_cooperator && opponent.is_cooperator
        agent.payoff += group.b
        opponent.payoff -= group.c
    end

    return
end

function play_games(group::Group)::Nothing
    reset_payoff(group)

    # if converged, don't play anymore
    if all_c(group) || all_d(group)
        return
    end

    # paly games for all agents
    for agent in group.agents
        opponent::Agent = rand([a for a in group.agents if a != agent])
        calc_payoff(group, agent, opponent)
    end

    calc_fitness(group)
end

mutable struct Population
    group_count::Int  # m
    group_size::Int   # n
    b_c_ratio::Float64
    w::Float64
    q::Float64
    groups::Vector{Group}
end

function Population(group_count::Int, group_size::Int, b_c_ratio::Float64, w::Float64, q::Float64)::Population
    groups = [Group(group_size, b_c_ratio, w) for _ in 1:group_count]
    groups[1].agents[1].is_cooperator = true
    return Population(group_count, group_size, b_c_ratio, w, q, groups)
end

all_c(population::Population)::Bool = all([all_c(g) for g in population.groups])

all_d(population::Population)::Bool = all([all_d(g) for g in population.groups])

function chose_an_agent_by_fitness(population::Population)::Agent
    all_agents = collect(Iterators.flatten([g.agents for g in population.groups]))
    sum_fitness = sum([a.fitness for a in all_agents])
    agent_index = rand() * sum_fitness
    for agent in all_agents
        agent_index -= agent.fitness
        if agent_index < 0
            return agent
        end
    end

    return rand(all_agents)
end

"""
At each time step, an individual from the entire population is chosen for reproduction proportional
to fitness. The offspring is added to the same group.
"""
function reproduce(population::Population)::Nothing
    agent::Agent = chose_an_agent_by_fitness(population)
    group::Group = [g for g in population.groups if agent in g.agents][1]
    new_agent = Agent()
    new_agent.is_cooperator = agent.is_cooperator
    push!(group.agents, new_agent)
    return
end

function intra_group_selection(population::Population)::Nothing
    for group in population.groups
        play_games(group)
    end
end

function between_group_selection(population::Population)::Nothing
    old_groups::Vector{Group} = population.groups
    new_groups::Vector{Group} = []

    while !isempty(old_groups)
        group = pop!(old_groups)
        if length(group.agents) > population.group_size
            if rand() < population.q
                # divide into two groups with probability q
                new_group_size = round(Int, length(group.agents) / 2)

                new_group1 = Group(population.group_size, population.b_c_ratio, population.w)
                new_group1.agents = group.agents[1:new_group_size]

                new_group2 = Group(population.group_size, population.b_c_ratio, population.w)
                new_group2.agents = group.agents[new_group_size + 1:length(group.agents)]

                if rand() < (length(old_groups) / (length(old_groups) + length(new_groups)))
                    deleteat!(old_groups, rand(1:length(old_groups)))
                else
                    deleteat!(new_groups, rand(1:length(new_groups)))
                end

                push!(new_groups, new_group1)
                push!(new_groups, new_group2)
            else
                # With probability 1− q, the group does not divide,
                # but a random individual of the group is eliminated.
                deleteat!(group.agents, rand(1:length(group.agents)))
                push!(new_groups, group)
            end
        else
            push!(new_groups, group)
        end
    end

    population.groups = new_groups

    return
end

function evolve(population::Population, generation_count::Int)::Bool
    _all_c = false

    for generation in 1:generation_count
        intra_group_selection(population)
        reproduce(population)
        between_group_selection(population)

        if all_c(population) || all_d(population)
            _all_c = all_c(population)
            break
        end
    end

    return _all_c
end

function run(;w::Float64 = 0.01, q::Float64 = 0.01, generation_count::Int = 100000, trial_count::Int = 10000)
    println("running on Julia $VERSION ($(Threads.nthreads()) Threads)")
    m_n_list = append!([(10, x * 5) for x in 1:5], [(x * 5, 10) for x in [1, 3, 4, 5]])
    b_c_ratio_list = [x / 4 for x in 4:20]
    param_list = [(b_c, m, n) for b_c in b_c_ratio_list for (m, n) in m_n_list]

    # file
    _now = format(now(), "yyyymmdd_HHMMSS")
    file_name = "data/$(_now).csv"
    stream = open(file_name, "w")

    for _ in 1:10
        for (b_c_ratio, group_count, group_size) in param_list
            println("group_count (m) =  $group_count, group_size (n) =  $group_size, b_c_ratio = $b_c_ratio")

            populations = [Population(group_count, group_size, b_c_ratio, w, q) for _ in 1:(trial_count / 10)]
            results = [evolve(population, generation_count) for population in populations]
            println(stream, join([
                group_count,
                group_size,
                round(b_c_ratio, digits=5),
                round(sum(results) / length(results), digits=5)
            ], ","))

            flush(stream)
        end
    end

    close(stream)
end

end  # end of module

if abspath(PROGRAM_FILE) == @__FILE__
    using .Simulation
    Simulation.run(w = 0.1, q = 0.001)
end

