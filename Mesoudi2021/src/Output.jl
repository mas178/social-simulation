module Output

using DataFrames
using Statistics
using Plots
export make_output_df, plot_A, plot_A_X
gr();

function make_output_df(r_max::Int64, t_max::Int64)::DataFrame
    # r: trial number
    # t: generation number
    # p: proportion of individuals who possess trait A
    return DataFrame(
        r = fill(0, r_max * t_max),
        t = fill(0, r_max * t_max),
        p = fill(-1.0, r_max * t_max),
        q = fill(-1.0, r_max * t_max)
    )
end

function plot_A(outputs_df::DataFrame, title::String)::Plots.Plot
    p = plot(
        outputs_df[outputs_df.r.== 1, :].p,
        ylims = (-0.01, 1.01),
        title = title,
        xlabel = "generation",
        ylabel = "p, proportion of agents with trait A",
        legend = false
    )
    for r = 2:maximum(outputs_df.r)
        plot!(outputs_df[outputs_df.r.== r, :].p)
    end
    
    mean_df = combine(groupby(outputs_df, :t), :p => mean)
    plot!(mean_df.p_mean, lw = 4, lc = :black)

    return p
end

function plot_A_X(outputs_df::DataFrame, title::String)::Plots.Plot
    p = plot(
        outputs_df[outputs_df.r.== 1, :].p,
        lc = :orange,
        ylims = (-0.01, 1.01),
        title = title,
        xlabel = "generation",
        ylabel = "p and q, proportion of agents with trait A and X",
        legend = false
    )
    for r = 2:maximum(outputs_df.r)
        plot!(outputs_df[outputs_df.r.== r, :].p, lc = :orange)
    end
    
    for r = 1:maximum(outputs_df.r)
        plot!(outputs_df[outputs_df.r.== r, :].q, lc = :royalblue)
    end
    
    mean_df = combine(groupby(outputs_df, :t), [:p => mean, :q => mean])
    plot!(mean_df.p_mean, lw = 4, lc = :orange)
    plot!(mean_df.q_mean, lw = 4, lc = :royalblue)

    return p
end

end  # module end