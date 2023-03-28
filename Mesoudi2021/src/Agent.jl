module Agent

using DataFrames
export make_agent_df, trait_ratio, A, B, C, X, Y

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
    agent_df = make_agent_AB_df(N, p_0)
    agent_df.payoff = [t == A ? 1.0 + s : 1.0 for t in agent_df.trait]
    return agent_df
end

# for model 4b
function make_agent_df(N::Int64, p_0::Float64, q_0::Float64, L::Float64, s::Float64)::DataFrame
    agent_df = make_agent_df(N, p_0, s)
    agent_df.trait2 = [trait2trait(t, q_0, L) for t in agent_df.trait]
    return agent_df
end

function make_agent_df_for_model07(N::Int, p_0::Float64, q_0::Float64)::DataFrame
    traits1 = [rand() < p_0 ? A : B for _ in 1:N]
    traits2 = [rand() < q_0 ? A : B for _ in 1:N]
    traits = vcat(traits1, traits2)
    groups = vcat(fill(1, N), fill(2, N))

    return DataFrame(trait = traits, group = groups)
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
    trait_count = if trait == A
        nrow(_agents_df[_agents_df.trait.==trait, :])
    elseif trait == X
        nrow(_agents_df[_agents_df.trait2.==trait, :])
    end

    return trait_count / nrow(_agents_df)
end

function trait_ratio(agent_df::DataFrame, trait::Agent.Trait, group::Int)::Float64
    _df = agent_df[agent_df.group.==group, :]
    trait_count = nrow(_df[_df.trait.==trait, :])

    return trait_count / nrow(_df)
end

end  # module end

