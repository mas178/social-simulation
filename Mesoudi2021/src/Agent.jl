module Agent

using DataFrames
export make_agent_df, trait_ratio, flip_AB, flip_ABC, trait2trait, A, B, C, X, Y

@enum Trait A B C X Y

# for model 1〜3, 5
function make_agent_AB_df(N::Int64, p_0::Float64)::DataFrame
    traits = [rand() < p_0 ? A : B for _ in 1:N]
    return DataFrame(trait = traits)
end

# for model 2c
function make_agent_ABC_df(N::Int64, p_0::Float64)::DataFrame
    traits = [rand() < p_0 ? A : rand([B, C]) for _ in 1:N]
    return DataFrame(trait = traits)
end

# for model 4a
function make_agent_df(N::Int64, p_0::Float64, s::Float64)::DataFrame
    trait_df = make_trait_df(N, p_0)
    trait_df.payoff = [t == A ? 1.0 + s : 1.0 for t in trait_df.trait]
    return trait_df
end

# for model 4b
function make_agent_df(N::Int64, p_0::Float64, q_0::Float64, L::Float64, s::Float64)::DataFrame
    trait_payoff_df = make_trait_payoff_df(N, p_0, s)
    trait_payoff_df.traits2 = [trait2trait(t, q_0, L) for t in trait_payoff_df.trait]
    return trait_payoff_df
end

# for model 4b
function trait2trait(trait::Trait, q_0::Float64, L::Float64)::Trait
    return if L > rand()
        trait == A ? X : Y
    else
        q_0 > rand() ? X : Y
    end
end

function flip_AB(t::Trait)::Trait
    return t == A ? B : A
end

function flip_ABC(t::Trait)::Trait
    return if t == A
        rand([B, C])
    elseif t == B
        rand([A, C])
    elseif t == C
        rand([A, B])
    end
end

function trait_ratio(_agents_df::DataFrame, trait::Trait)::Float64
    return nrow(_agents_df[_agents_df.trait.==trait, :]) / nrow(_agents_df)
end

end  # module end

