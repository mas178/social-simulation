module Agent
    using Agents: AbstractAgent

    # Strategy
    const C = true   # Cooperate
    const D = false  # Defect

    mutable struct Player <: AbstractAgent
        id::Int
        pos::Int
        strategy::Bool # C or D
        next_strategy::Bool # C or D
        payoff::Float32 # 6 digits

        Player(id::Int, C_rate::Float64) = new(id, id, rand() < C_rate, D, Float32(0))
        Player(id::Int, strategy::Bool) = new(id, id, strategy, D, Float32(0))
        Player(strategy::Bool) = new(-1, strategy)
    end
end
