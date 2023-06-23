module Model18_19

module Agent
using DataFrames
using StatsBase

export make_agent_df, individual_learning!, update_fitnesses!, mutation_18a!, mutation_18b!

function make_agent_df(N::Int)::DataFrame
    DataFrame(learning=fill("IL", N), behaviour=fill(false, N), fitness=fill(0.0, N))
end

function individual_learning!(agent_df::DataFrame, pᵢ::Float64)::Nothing
    weights = Weights([pᵢ, 1 - pᵢ])
    il_vec = agent_df.learning .== "IL"
    agent_df[il_vec, :behaviour] .= sample([true, false], weights, sum(il_vec))
    return
end

function update_fitnesses!(agent_df::DataFrame, b::Float64, cᵢ::Float64)::Nothing
    # 間違った行動を取っていれば 1 の、正しい行動を取っていれば 1 + b の適応度を獲得する
    agent_df.fitness .= [behaviour ? 1.0 + b : 1.0 for behaviour in agent_df.behaviour]

    # 個人的学習のコストを適応度から差し引く
    agent_df[agent_df.learning.=="IL", :fitness] .-= cᵢ

    return
end

function mutation_18a!(agent_df::DataFrame, μ::Float64)::Nothing
    mutate = rand(nrow(agent_df)) .< μ

    il_vec = agent_df.learning .== "IL"
    sl_vec = agent_df.learning .== "SL"

    agent_df[il_vec.&&mutate, :learning] .= "SL"
    agent_df[sl_vec.&&mutate, :learning] .= "IL"

    return
end

function mutation_18b!(agent_df::DataFrame, μ::Float64)::Nothing
    mutate = rand(nrow(agent_df)) .< μ

    il_vec = (agent_df.learning .== "IL" .&& mutate)
    sl_vec = (agent_df.learning .== "SL" .&& mutate)
    cl_vec = (agent_df.learning .== "CL" .&& mutate)

    agent_df[il_vec, :learning] .= rand(["SL", "CL"], sum(il_vec))
    agent_df[sl_vec, :learning] .= rand(["CL", "IL"], sum(sl_vec))
    agent_df[cl_vec, :learning] .= rand(["IL", "SL"], sum(cl_vec))

    return
end

function mutation_19!(agent_df::DataFrame, μ::Float64)::Nothing
    mutate = rand(nrow(agent_df)) .< μ

    il_vec = (agent_df.learning .== "IL" .&& mutate)
    ub_vec = (agent_df.learning .== "UB" .&& mutate)
    pb_vec = (agent_df.learning .== "PB" .&& mutate)
    cb_vec = (agent_df.learning .== "CB" .&& mutate)

    agent_df[il_vec, :learning] .= rand(["UB", "PB", "CB"], sum(il_vec))
    agent_df[ub_vec, :learning] .= rand(["IL", "PB", "CB"], sum(ub_vec))
    agent_df[pb_vec, :learning] .= rand(["IL", "UB", "CB"], sum(pb_vec))
    agent_df[cb_vec, :learning] .= rand(["IL", "UB", "PB"], sum(cb_vec))

    return
end
end # module Agent

module Output
using DataFrames
using Plots
using StatsBase

export make_output_df, record_frequency_and_fitnesses!, plot_model18

function make_output_df(time_steps::Int)::DataFrame
    DataFrame(
        ILfreq=fill(0.0, time_steps),
        SLfreq=fill(0.0, time_steps),
        CLfreq=fill(0.0, time_steps),
        UBfreq=fill(0.0, time_steps),
        PBfreq=fill(0.0, time_steps),
        CBfreq=fill(0.0, time_steps),
        ILfitness=fill(0.0, time_steps),
        SLfitness=fill(0.0, time_steps),
        CLfitness=fill(0.0, time_steps),
        UBfitness=fill(0.0, time_steps),
        PBfitness=fill(0.0, time_steps),
        CBfitness=fill(0.0, time_steps),
        predictedILfitness=fill(0.0, time_steps),
    )
end

function record_frequency_and_fitnesses!(
    output_df::DataFrame,
    agent_df::DataFrame,
    time_step::Int,
)::Nothing
    N = nrow(agent_df)
    il_vec = agent_df.learning .== "IL"
    sl_vec = agent_df.learning .== "SL"
    cl_vec = agent_df.learning .== "CL"
    ub_vec = agent_df.learning .== "UB"
    pb_vec = agent_df.learning .== "PB"
    cb_vec = agent_df.learning .== "CB"

    output_df[time_step, :ILfreq] = sum(il_vec) / N
    output_df[time_step, :SLfreq] = sum(sl_vec) / N
    output_df[time_step, :CLfreq] = sum(cl_vec) / N
    output_df[time_step, :UBfreq] = sum(ub_vec) / N
    output_df[time_step, :PBfreq] = sum(pb_vec) / N
    output_df[time_step, :CBfreq] = sum(cb_vec) / N

    output_df[time_step, :ILfitness] = mean(agent_df[il_vec, :fitness])
    output_df[time_step, :SLfitness] = mean(agent_df[sl_vec, :fitness])
    output_df[time_step, :CLfitness] = mean(agent_df[cl_vec, :fitness])
    output_df[time_step, :UBfitness] = mean(agent_df[ub_vec, :fitness])
    output_df[time_step, :PBfitness] = mean(agent_df[pb_vec, :fitness])
    output_df[time_step, :CBfitness] = mean(agent_df[cb_vec, :fitness])

    return
end

function plot_model18(df::DataFrame)::Nothing
    include_CL = (df.CLfreq != fill(0.0, nrow(df)))

    p1 = plot(xlab="generation", ylab="proportion of each learner", legend=false)
    plot!(df.SLfreq, lc=:orange)
    include_CL && plot!(df.ILfreq, lc=:royalblue)
    include_CL && plot!(df.CLfreq, lc=:green)

    p2 = plot(ylim=(0.5, 2), xlab="generation", ylab="mean fitness")
    plot!(df.SLfitness, lc=:orange, label="social learners")
    plot!(df.ILfitness, lc=:royalblue, label="individual learners")
    include_CL && plot!(df.CLfitness, lc=:green, label="critical learners")

    # 集団全体の適応度
    if !include_CL
        POPfitness = df.SLfreq .* df.SLfitness .+ df.ILfreq .* df.ILfitness
        plot!(POPfitness, lc=:grey, label="population")
    end

    hline!([df.predictedILfitness[1]], ls=:dash, lc=:black, label=false)

    println("個人的学習者の平均適応度: $(mean(filter(!isnan, df.ILfitness)))")
    println("社会的学習者の平均適応度: $(mean(filter(!isnan, df.SLfitness)))")
    include_CL && println("クリティカル学習者の平均適応度: $(mean(filter(!isnan, df.CLfitness)))")

    display(plot(p1, p2, size=(800, 450)))
end
end # module Output
end # module Model18_19
