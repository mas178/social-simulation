# cd social-simulation/Santos2008
# julia src/exec.jl
using LightGraphs: SimpleGraph, ne, nv, barabasi_albert
using DataFrames: DataFrame
using Statistics: mean
using Agents: run!, dummystep
using Dates

include("model.jl")

# η を r に変換する
calc_r(G::SimpleGraph, η::Float64)::Float64 = η * (2 * ne(G) / nv(G) + 1) # 握手の補題: 次数の総和 は 総枝数の2倍に等しい

function run_simulation(network_type::Symbol, cost_model::Symbol, η::Float64; N_gen::Int = 10^5, N_sim::Int = 10)::Float64
    # Log
    (abspath(PROGRAM_FILE) == @__FILE__) && println("network_type = $network_type, cost_model = $cost_model, η = $η")

    f_c = 0.0

    Threads.@threads for _ in 1:N_sim
        G = barabasi_albert(10^3, 2)
        for _ in 1:N_sim
            model = Model.build_model(;G, cost_model, r = calc_r(G, η))
            temp_df, _ = run!(
                model,
                dummystep,
                Model.model_step!,
                N_gen;
                adata = [(:strategy, mean)],
                when = (N_gen - 1999):(N_gen + 1)
            )
            f_c += mean(temp_df.mean_strategy)
        end
    end

    return f_c / N_sim^2
end

if abspath(PROGRAM_FILE) == @__FILE__
    # 10分 x 10 x 7 = 700分 (12時間)
    date_time = Dates.format(now(), "yyyymmdd_HHMMSS")
    file_name = "data/output_$(date_time).csv"

    for cost_model in [:fixed_cost, :variable_cost]
        for η in 0.5:0.05:0.8 # 0.2:0.05:0.8
            @time c_rate = run_simulation(:scale_free, cost_model, η; N_gen = 10^5, N_sim = 7)
            open(file_name, "a") do f
                println(f, "$(:scale_free),$(cost_model),$(η),$(c_rate)")
            end
        end
    end
end
