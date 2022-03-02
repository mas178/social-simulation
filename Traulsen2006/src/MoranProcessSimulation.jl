module MoranProcessSimulation

struct Population
    N::Int
    i::Int
    agents::Vector{Bool}
    Population(N::Int, i::Int) = new(N, i, [j <= i for j in 1:N])
end

all_true(population::Population)::Bool = all(population.agents)

all_false(population::Population)::Bool = !any(population.agents)

function one_generation(population::Population)::Nothing
    agent_for_reproduction = rand(population.agents)

    # kill one agent
    deleteat!(population.agents, rand(1:length(population.agents)))

    # reproduce one agent
    push!(population.agents, agent_for_reproduction)

    return
end

function evolve(population::Population)::Nothing
    while !(all_true(population) || all_false(population))
        one_generation(population)
    end

    return
end

end  # end of module

if abspath(PROGRAM_FILE) == @__FILE__
    using .MoranProcessSimulation
    const sim = MoranProcessSimulation  # alias
    population = sim.Population(10, 1)
    sim.evolve(population)
    println(population)
end

