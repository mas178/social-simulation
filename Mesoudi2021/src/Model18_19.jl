module Model18_19

module Agent
using DataFrames
using StatsBase

export make_agent_df, individual_learning!, individual_learning_for_incorrect_sl!, social_learning!, critical_learning_and_update_fitness!, social_learning_for_critical_learners!, update_fitnesses!, selection_and_reproduction!, mutation_18a!, mutation_18b!, mutation_19!

function make_agent_df(N::Int)::DataFrame
    DataFrame(learning=fill("IL", N), behaviour=fill(false, N), fitness=fill(0.0, N))
end

function individual_learning!(agent_df::DataFrame, pᵢ::Float64)::Nothing
    weights = Weights([pᵢ, 1 - pᵢ])
    il_vec = agent_df.learning .== "IL"
    agent_df[il_vec, :behaviour] .= sample([true, false], weights, sum(il_vec))
    return
end

# for Model 19a
function individual_learning_for_incorrect_sl!(agent_df::DataFrame, pᵢ::Float64)::Nothing
    weights = Weights([pᵢ, 1 - pᵢ])
    incorrect_sl = agent_df.learning .!= "IL" .&& .!agent_df.behaviour
    agent_df[incorrect_sl, :behaviour] .= sample([true, false], weights, sum(incorrect_sl))
    return
end

function social_learning!(agent_df::DataFrame, v::Float64)::Nothing
    sl_vec = agent_df.learning .!= "IL"  # CLが入ってくる可能性があることに注意

    # if environment has changed, all social learners have incorrect beh
    if v < rand()
        agent_df[sl_vec, :behaviour] .= false
    else
        # otherwise for each social learner, pick a random demonstrator from previous timestep
        # if demonstrator is correct, adopt correct beh
        dem = rand(agent_df.behaviour, nrow(agent_df))
        agent_df[sl_vec.&&dem, :behaviour] .= true  # correct
        agent_df[sl_vec.&&.!dem, :behaviour] .= false  # incorrect
    end

    return
end

function critical_learning_and_update_fitness!(
    agent_df::DataFrame,
    pᵢ::Float64,  # chance of discovering the correct behaviour
    b::Float64,   # 正しい行動を取ったときのベネフィット
    cᵢ::Float64,  # 個人的学習・クリティカル学習のコスト
)::Nothing
    cl_vec = agent_df.learning .== "CL" .&& agent_df.behaviour .== false
    weights = Weights([pᵢ, 1 - pᵢ])
    agent_df[cl_vec, :behaviour] .= sample([true, false], weights, sum(cl_vec))

    # クリティカル学習者の適応度を更新する
    agent_df[cl_vec.&&agent_df.behaviour, :fitness] .+= b
    agent_df[cl_vec, :fitness] .-= cᵢ

    return
end

# for Model 19a
function social_learning_for_critical_learners!(
    agent_df::DataFrame,
    v::Float64,
    n::Int,
    f::Float64,
)::Nothing
    il_vec = agent_df.learning .== "IL"  # individual learning
    ub_vec = agent_df.learning .== "UB"  # unbiased learning
    pb_vec = agent_df.learning .== "PB"  # payoff bias learning
    cb_vec = agent_df.learning .== "CB"  # conformist bias learning

    # if environment has changed, all social learners have incorrect beh
    if v < rand()
        agent_df[.!il_vec, :behaviour] .= false
    else
        # otherwise create matrix for holding n demonstrators for N agents
        # fill with randomly selected agents from previous gen
        N = nrow(agent_df)
        dem = rand(agent_df.behaviour, N, n)
        row_sum_dems = vec(sum(dem, dims = 2))

        # for UBs, copy the behaviour of the 1st dem in dems
        agent_df[ub_vec.&&dem[:, 1], :behaviour] .= true  # correct
        agent_df[ub_vec.&&.!dem[:, 1], :behaviour] .= false  # incorrect

        # for PB, copy correct if at least one of dems is correct
        agent_df[pb_vec.&&row_sum_dems.>0, :behaviour] .= true  # correct
        agent_df[pb_vec.&&row_sum_dems.==0, :behaviour] .= false  # incorrect

        # for CB, copy majority behaviour according to parameter f
        copy_probs = row_sum_dems .^ f ./ (row_sum_dems .^ f + (n .- row_sum_dems) .^ f)
        probs = rand(N)
        agent_df[cb_vec.&&probs.<copy_probs, :behaviour] .= true # correct
        agent_df[cb_vec.&&probs.>=copy_probs, :behaviour] .= false # incorrect
    end

    return
end

function update_fitnesses!(agent_df::DataFrame, b::Float64, cᵢ::Float64)::Nothing
    # 間違った行動を取っていれば 1 の、正しい行動を取っていれば 1 + b の適応度を獲得する
    agent_df.fitness .= [behaviour ? 1.0 + b : 1.0 for behaviour in agent_df.behaviour]

    # 個人的学習のコストを適応度から差し引く
    agent_df[agent_df.learning.=="IL", :fitness] .-= cᵢ

    return
end

function update_fitnesses!(agent_df::DataFrame, b::Float64, c_i::Float64, c_p::Float64, c_c::Float64)::Nothing
    # 間違った行動を取っていれば 1 の、正しい行動を取っていれば 1 + b の適応度を獲得する
    agent_df.fitness .= [behaviour ? 1.0 + b : 1.0 for behaviour in agent_df.behaviour]

    # 個人的学習のコストを適応度から差し引く
    agent_df[agent_df.learning.=="IL", :fitness] .-= c_i
    agent_df[agent_df.learning.=="PB", :fitness] .-= c_p
    agent_df[agent_df.learning.=="CB", :fitness] .-= c_c
    agent_df[agent_df.learning.!= "IL" .&& .!agent_df.behaviour, :fitness] .-= c_i

    return
end

function selection_and_reproduction!(agent_df::DataFrame)::Nothing
    relative_fitness = agent_df.fitness ./ sum(agent_df.fitness)
    agent_df.learning .=
        sample(agent_df.learning, Weights(relative_fitness), nrow(agent_df))
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

export make_output_df, record_frequency_and_fitnesses!, plot_model18, plot_model19

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

function plot_model19(df::DataFrame)::Nothing
    # 各学習者の頻度
    freq_plot = plot(
        ylim = (-0.02, 1),
        xlab = "generation",
        ylab = "proportion of each learner",
        legend = false,
    )
    plot!(df.ILfreq, lc = :royalblue)
    plot!(df.UBfreq, lc = :orange)
    plot!(df.PBfreq, lc = :springgreen4)
    plot!(df.CBfreq, lc = :orchid)

    # 各学習者の適応度
    fitness_plot = plot(ylim = (0.5, 2), xlab = "generation", ylab = "mean fitness")
    plot!(df.ILfitness, lc = :royalblue, label = "individual learning (IL)")
    plot!(df.UBfitness, lc = :orange, label = "unbiased transmission (UB)")
    plot!(df.PBfitness, lc = :springgreen4, label = "payoff bias (PB)")
    plot!(df.CBfitness, lc = :orchid, label = "conformist bias (CB)")

    hline!([df.predictedILfitness[1]], ls = :dash, lc = :black, label = false)

    display(plot(freq_plot, fitness_plot, size = (800, 450)))
end
end # module Output
end # module Model18_19
