# Change to current directory and activate environment
cd(@__DIR__)
using Pkg
Pkg.activate("../../../.")

using Distributed
# set the number of workers for parallel computing
addprocs(10)

@everywhere include("../../../src/OrdinalPatterns.jl")
@everywhere using .OrdinalPatterns
@everywhere using LinearAlgebra
@everywhere using JLD2
@everywhere BLAS.set_num_threads(1)

# Vector and delay combinations
reps = 10^3 # Increase the number of replications to 10^5 for reproduction of the results in the paper
lam = 0.1
MN_vec = [(11, 11), (16, 16), (26, 26), (41, 26)]
d1d2_vec = [(1, 1), (2, 2), (3, 3)]
w_max = 3

# Load critical values
cl_sacf_mat = load_object("../climits/cl_sacf_delays.jld2")
cl_sop_mat = load_object("../climits/cl_sop_delays.jld2")
cl_sacf_bp_mat = load_object("../climits/cl_sacf_bp.jld2")
cl_sop_bp_mat = load_object("../climits/cl_sop_bp.jld2")

# ---------------------------------------------------------------- #
# ----                      SACF and SOP                -----------#
# ---------------------------------------------------------------- #

# Results for SAR(1)
arl_sacf_sar1_mat = zeros(length(MN_vec), length(d1d2_vec))
arlse_sacf_sar1_mat = similar(arl_sacf_sar1_mat)
arl_sop_sar1_mat = similar(arl_sacf_sar1_mat)
arlse_sop_sar1_mat = similar(arl_sacf_sar1_mat)

for (i, MN) in enumerate(MN_vec)
    M = MN[1]
    N = MN[2]
    for (j, d1d2) in enumerate(d1d2_vec)
        d1 = d1d2[1]
        d2 = d1d2[2]
        sar1 = SAR1((0.1, 0.1, 0.1, 0.1), M, N, Normal(0, 1), nothing, 20)

        # Compute ARL for SACF for SAR(1)
        sacf_results = arl_sacf_oc(sar1, lam, cl_sacf_mat[i, j], d1, d2, reps)
        arl_sacf_sar1_mat[i, j] = sacf_results[1]
        arlse_sacf_sar1_mat[i, j] = sacf_results[2]

        # Compute ARL for SOP for SAR(1)
        sop_results = arl_sop_oc(sar1, lam, cl_sop_mat[i, j], d1, d2, reps; chart_choice=3)
        arl_sop_sar1_mat[i, j] = sop_results[1]
        arlse_sop_sar1_mat[i, j] = sop_results[2]
        println("Progress -> SAR(1): i: $i, j: $j")
    end
end

# --- SAR(1) with outliers
arl_sacf_sar1_outl_mat = zeros(length(MN_vec), length(d1d2_vec))
arlse_sacf_sar1_outl_mat = similar(arl_sacf_sar1_outl_mat)
arl_sop_sar1_outl_mat = similar(arl_sacf_sar1_outl_mat)
arlse_sop_sar1_outl_mat = similar(arl_sacf_sar1_outl_mat)

for (i, MN) in enumerate(MN_vec)
    M = MN[1]
    N = MN[2]
    for (j, d1d2) in enumerate(d1d2_vec)
        d1 = d1d2[1]
        d2 = d1d2[2]
        sar1_outl = SAR1((0.1, 0.1, 0.1, 0.1), M, N, Normal(0, 1), BinomialCvec(0.1, [-5, 5]), 20)

        # Compute ARL for SACF for SAR(1) with outliers
        sacf_results = arl_sacf_oc(sar1_outl, lam, cl_sacf_mat[i, j], d1, d2, reps)
        arl_sacf_sar1_outl_mat[i, j] = sacf_results[1]
        arlse_sacf_sar1_outl_mat[i, j] = sacf_results[2]

        # Compute ARL for SOP for SAR(1) with outliers
        sop_results = arl_sop_oc(sar1_outl, lam, cl_sop_mat[i, j], d1, d2, reps; chart_choice=3)
        arl_sop_sar1_outl_mat[i, j] = sop_results[1]
        arlse_sop_sar1_outl_mat[i, j] = sop_results[2]
        println("Progress -> SAR(1) with outliers: i: $i, j: $j")
    end
end

# ---------------------------------------------------------------- #
# ----                BP-SACF and BP-SOP                -----------#
# ---------------------------------------------------------------- #

# Results for SAR(1) without outliers
arl_sacf_bp_sar1_mat = zeros(length(MN_vec), length(d1d2_vec))
arlse_sacf_bp_sar1_mat = similar(arl_sacf_bp_sar1_mat)
arl_sop_bp_sar1_mat = similar(arl_sacf_bp_sar1_mat)
arlse_sop_bp_sar1_mat = similar(arl_sacf_bp_sar1_mat)

for (i, MN) in enumerate(MN_vec)
    M = MN[1]
    N = MN[2]
    for w in 1:w_max
        sar1 = SAR1((0.1, 0.1, 0.1, 0.1), M, N, Normal(0, 1), nothing, 20)

        # Compute ARL for SACF for SAR(1)
        sacf_results = arl_sacf_bp_oc(sar1, lam, cl_sacf_bp_mat[i, w], w, reps)
        arl_sacf_bp_sar1_mat[i, w] = sacf_results[1]
        arlse_sacf_bp_sar1_mat[i, w] = sacf_results[2]

        # Compute ARL for SOP for SAR(1)
        sop_results = arl_sop_bp_oc(sar1, lam, cl_sop_bp_mat[i, w], w, reps; chart_choice=3)
        arl_sop_bp_sar1_mat[i, w] = sop_results[1]
        arlse_sop_bp_sar1_mat[i, w] = sop_results[2]
        println("Progress -> SAR(1): i: $i, w: $w")
    end
end

# --- SAR(1) with outliers
arl_sacf_bp_sar1_outl_mat = zeros(length(MN_vec), length(d1d2_vec))
arlse_sacf_bp_sar1_outl_mat = similar(arl_sacf_bp_sar1_outl_mat)
arl_sop_bp_sar1_outl_mat = similar(arl_sacf_bp_sar1_outl_mat)
arlse_sop_bp_sar1_outl_mat = similar(arl_sacf_bp_sar1_outl_mat)

for (i, MN) in enumerate(MN_vec)
    M = MN[1]
    N = MN[2]
    for w in 1:w_max
        sar1_outl = SAR1((0.1, 0.1, 0.1, 0.1), M, N, Normal(0, 1), BinomialCvec(0.1, [-5, 5]), 20)

        # Compute ARL for SACF for SAR(1) with outliers
        sacf_results = arl_sacf_bp_oc(sar1_outl, lam, cl_sacf_bp_mat[i, w], w, reps)
        arl_sacf_bp_sar1_outl_mat[i, w] = sacf_results[1]
        arlse_sacf_bp_sar1_outl_mat[i, w] = sacf_results[2]

        # Compute ARL for SOP for SAR(1) with outliers
        sop_results = arl_sop_bp_oc(sar1_outl, lam, cl_sop_bp_mat[i, w], w, reps; chart_choice=3)
        arl_sop_bp_sar1_outl_mat[i, w] = sop_results[1]
        arlse_sop_bp_sar1_outl_mat[i, w] = sop_results[2]
        println("Progress -> SAR(1) with outliers: i: $i, w: $w")
    end
end

# compare results with Table A.18

# ARL results
hcat(arl_sop_sar1_mat, arl_sacf_sar1_mat, arl_sop_sar1_outl_mat, arl_sacf_sar1_outl_mat)

# Maximum ARL standard error
findmax([
    maximum(arlse_sop_sar1_mat),
    maximum(arlse_sacf_sar1_mat),
    maximum(arlse_sop_sar1_outl_mat),
    maximum(arlse_sacf_sar1_outl_mat)
])

# compare results with Table A.19

# ARL results
hcat(
    arl_sop_bp_sar1_mat,
    arl_sacf_bp_sar1_mat,
    arl_sop_bp_sar1_outl_mat,
    arl_sacf_bp_sar1_outl_mat
)

# Maximum ARL standard error
findmax([
    maximum(arlse_sop_bp_sar1_mat),
    maximum(arlse_sacf_bp_sar1_mat),
    maximum(arlse_sop_bp_sar1_outl_mat),
    maximum(arlse_sacf_bp_sar1_outl_mat)
])

# Remove workers
rmprocs(workers())