
"""
Compute a 4D array to lookup the index of the sops. The original SOPs are based on ranks. Here we use sortperm which computes the order of the elements in the vector.
"""
function compute_lookup_array_sop()

  p_sops = zeros(Int, 24, 4)
  sort_tmp = zeros(Int, 4)

  for (i, j) in enumerate(collect(permutations(1:4)))
    sortperm!(sort_tmp, j)
    @views p_sops[i, :] = sort_tmp
  end

  # Construct multi-dimensional lookup array 
  lookup_array = zeros(Int, 4, 4, 4, 4)

  for i in axes(p_sops, 1)
    @views lookup_array[p_sops[i, :][1], p_sops[i, :][2], p_sops[i, :][3], p_sops[i, :][4]] = i
  end

  return lookup_array

end


"""
Create and return the index of the sops for sortperm values. 
The type frequencies are based on the ranks of the sops, but we use sortperm to 
compute the order of the elements in the vector. 
"""
# Function that returns SOP indices for sortperm values
function create_index_sop(; refinement=0)

  @assert refinement in 0:3 "refinement must be in 0:3"

  # Classical approach as in Weiss and Kim (2024) and Adämmer et al. (2024)
  if refinement == 0

    s_1 = [1, 3, 8, 11, 14, 17, 22, 24]
    s_2 = [2, 5, 7, 9, 16, 18, 20, 23]
    s_3 = [4, 6, 10, 12, 13, 15, 19, 21]
    return [s_1, s_2, s_3]

    # See Equation (8) in Weiss and Kim (2025)  
  elseif refinement == 1

    s_11 = [1, 11, 14, 24]
    s_12 = [3, 8, 17, 22]
    s_21 = [2, 9, 18, 20]
    s_22 = [5, 7, 16, 23]
    s_31 = [4, 12, 15, 19]
    s_32 = [6, 10, 13, 21]
    return [s_11, s_12, s_21, s_22, s_31, s_32]

    # "Direction types" -> (9) in Weiss and Kim (2025)  
  elseif refinement == 2
    s_11 = [1, 8, 17, 24]
    s_12 = [3, 11, 14, 22]
    s_21 = [2, 7, 18, 23]
    s_22 = [5, 9, 16, 20]
    s_31 = [4, 6, 10, 12]
    s_32 = [13, 15, 19, 21]
    return [s_11, s_12, s_21, s_22, s_31, s_32]

    # "Diagonal types -> (10) in Weiss and Kim (2025)  
  else # refinement == 3
    s_11 = [1, 3, 22, 24]
    s_12 = [8, 11, 14, 17]
    s_21 = [7, 9, 20, 23]
    s_22 = [2, 5, 16, 18]
    s_31 = [13, 15, 19, 21]
    s_32 = [4, 6, 10, 12]
    return [s_11, s_12, s_21, s_22, s_31, s_32]
  end

end

"""
    compute_p_array(data::Array{T,3})

Compute the matrix of p-hat values for a given 3D array of data when the delays are integers. These values are used for bootstrapping. 
"""
function compute_p_array(data::Array{T,3}, d1::Int, d2::Int; chart_choice=3, refinement=refinement, add_noise=false) where {T<:Real}

  # Check input parameters
  @assert 1 <= chart_choice <= 7 "chart_choice must be between 1 and 7"
  if chart_choice in 1:4
    @assert refinement == 0 "refinement must be 0 for chart_choice 1-4"
  elseif chart_choice in 5:7
    @assert 1 <= refinement <= 3 "refinement must be 1-3 for chart_choices 5-7"
  end

  # pre-allocate  
  m = size(data, 1) - d1
  n = size(data, 2) - d2
  lookup_array_sop = compute_lookup_array_sop()
  p_mat = zeros(size(data, 3), 3)

  # indices for sum of frequencies
  index_sop = create_index_sop(refinement=refinement)
  #s_1 = index_sop[1]
  #s_2 = index_sop[2]
  #s_3 = index_sop[3]

  # Add noise?
  if add_noise
    data = data .+ rand(size(data, 1), size(data, 2), size(data, 3))
  end

  # Function to fill p_mat with p_hat values used in parallel computation with Threads.@threads
  function fill_p_mat!(
    i, data_tmp, p_mat, lookup_array_sop, m, n, d1, d2, s_all, chart_choice, refinement 
  )

    p_hat = zeros(1, 3)
    sop = zeros(4)
    sop_freq = zeros(Int, 24)
    win = zeros(Int, 4)

    # Compute frequencies of sops
    sop_frequencies!(m, n, d1, d2, lookup_array_sop, data_tmp, sop, win, sop_freq)

    # Compute sum of frequencies for each group
    fill_p_hat!(p_hat, chart_choice, refinement, sop_freq, m, n, s_all)

    p_mat[i, :] = p_hat

    # Reset win and sop_freq
    fill!(win, 0)
    fill!(sop_freq, 0)
    fill!(p_hat, 0)

  end

  # Fill p_mat in parallel
  Threads.@threads for i in axes(data, 3)

    # Compute frequencies of sops
    @views data_tmp = data[:, :, i]
    fill_p_mat!(
      i, data_tmp, p_mat, lookup_array_sop, m, n, d1, d2, index_sop, chart_choice, refinement
    )

  end

  return p_mat

end


"""
compute_p_array(data::Array{Float64,3})

Compute the matrix of p-hat values for a given 3D array of data when the delays are vectors of integers. These values are used for bootstrapping to compute critcial limits for the BP-statistics. 
"""
function compute_p_array_bp(data::Array{T,3}, w::Int; chart_choice=3,
  refinement::Int=0, add_noise=false) where {T<:Real}

  # pre-allocate
  lookup_array_sop = compute_lookup_array_sop()
  d1_d2_combinations = Iterators.product(1:w, 1:w)
  p_array = zeros(size(data, 3), 3, length(d1_d2_combinations))

  # indices for sum of type frequencies  
  index_sop = create_index_sop(refinement=refinement)
  #s_1 = index_sop[1]
  #s_2 = index_sop[2]
  #s_3 = index_sop[3]

  # Add noise?
  if add_noise
    data = data .+ rand(size(data, 1), size(data, 2), size(data, 3))
  end

  # Function to fill 'p_array' with 'p_hat' values. 
  # This function will be called in parallel via Threads.@threads below
  function fill_p_array_bp!(
    i, data_tmp, p_array, d1_d2_combinations, lookup_array_sop, s_all, chart_choice, refinement
  )

    # Initialize thread-local variables
    M_rows = size(data_tmp, 1)
    N_cols = size(data_tmp, 2)
    sop = zeros(4)
    win = zeros(Int, 4)
    sop_freq = zeros(Int, 24)
    p_hat = zeros(1, 3)

    for (j, (d1, d2)) in enumerate(d1_d2_combinations)

      m = M_rows - d1
      n = N_cols - d2

      # Compute frequencies of sops
      sop_frequencies!(m, n, d1, d2, lookup_array_sop, data_tmp, sop, win, sop_freq)

      # Compute sum of frequencies for each group
      fill_p_hat!(p_hat, chart_choice, refinement, sop_freq, m, n, s_all)

      p_array[i, :, j] = p_hat

      # Reset win and sop_freq
      fill!(sop_freq, 0)
      fill!(p_hat, 0)
    end

  end

  # Fill p_array in parallel
  Threads.@threads for i in axes(data, 3)

    @views fill_p_array_bp!(
      i, data[:, :, i], p_array, d1_d2_combinations, lookup_array_sop, index_sop, chart_choice, refinement
    )

  end

  return p_array

end

# In-place function to sort vector with sops
function order_vec!(x, ix)

  sortperm!(ix, x)

  return ix

end

#--- Compute absolute frequencies of sops
function sop_frequencies!(m, n, d1, d2, lookup_array_sop, data, sop, win, sop_freq)

  # Loop through data to fill sop vector
  for j in 1:n
    for i in 1:m

      sop[1] = data[i, j]
      sop[2] = data[i, j+d2]
      sop[3] = data[i+d1, j]
      sop[4] = data[i+d1, j+d2]

      # Order 'sop' in-place and save results in 'win'
      sortperm!(win, sop)

      # Get index
      ind2 = lookup_array_sop[win[1], win[2], win[3], win[4]]

      # Add 1 to index position
      sop_freq[ind2] += 1
    end
  end

  return sop_freq

end
#

# Fill p_hat with the sum of frequencies and compute relative frequencies
function fill_p_hat!(p_hat, chart_choice, refinement, sop_freq, m, n, s_all) #s_1, s_2, s_3)
  #

  # # Only needed to compute charts 1 and 4
  # if chart_choice in (1, 4)
  #   for i in s_1
  #     p_hat[1] += sop_freq[i]
  #   end
  # end

  # # Only needed to compute charts 2 and 4 
  # if chart_choice in (2, 4)
  #   for i in s_2
  #     p_hat[2] += sop_freq[i]
  #   end
  # end

  # # Only needed to compute charts 2 and 3
  # if chart_choice in (2, 3)
  #   for i in s_3
  #     p_hat[3] += sop_freq[i]
  #   end
  # end

  # For classical appraoch
  if refinement == 0
    if chart_choice == 1
      for i in s_all[1]
        p_hat[1] += sop_freq[i]
      end

    elseif chart_choice == 2
      for (i, j) in zip(s_all[2], s_all[3])
        p_hat[2] += sop_freq[i]
        p_hat[3] += sop_freq[j]
      end

    elseif chart_choice == 3
      for i in s_all[3]
        p_hat[3] += sop_freq[i]
      end

    elseif chart_choice == 4
      for (i, j) in zip(s_all[1], s_all[2])
        p_hat[1] += sop_freq[i]
        p_hat[2] += sop_freq[j]
      end

    elseif chart_choice in 5:7
      for (i, j, k) in zip(s_all[1], s_all[2], s_all[3])
        p_hat[1] += sop_freq[i]
        p_hat[2] += sop_freq[j]
        p_hat[3] += sop_freq[k]
      end
    end

    # For refined computations  
  else
    for (i, j, k, l, m, n) in zip(
      s_all[1], s_all[2], s_all[3], s_all[4], s_all[5], s_all[6]
    )
      p_hat[1] += sop_freq[i]
      p_hat[2] += sop_freq[j]
      p_hat[3] += sop_freq[k]
      p_hat[4] += sop_freq[l]
      p_hat[5] += sop_freq[m]
      p_hat[6] += sop_freq[n]
    end

  end

  # Compute relative frequencies
  p_hat ./= m * n

end

# function fill_p_hat_refined!(p_hat, sop_freq, m, n, s_11, s_12, s_21, s_22, s_31, s_32)

#   for (i, j, k, l, m, n) in zip(s_11, s_12, s_21, s_22, s_31, s_32)
#     p_hat[1] += sop_freq[i]
#     p_hat[2] += sop_freq[j]
#     p_hat[3] += sop_freq[k]
#     p_hat[4] += sop_freq[l]
#     p_hat[5] += sop_freq[m]
#     p_hat[6] += sop_freq[n]
#   end

#   # Compute relative frequencies
#   p_hat ./= m * n

# end

# # Function to get sensible starting values for the control limit
# function init_vals_sop(lam, dist, runs; chart_choice, p_quantile)

#   # Pre-allocate
#   lookup_array_sop = compute_lookup_array_sop()
#   sop_freq = zeros(24)
#   win = zeros(Int, 4)
#   data = zeros(m + 1, n + 1)
#   p_ewma = zeros(3)
#   p_hat = zeros(3)
#   vals = zeros(runs)
#   sop = zeros(4)

#   fill!(p_ewma, 1.0 / 3.0)
#   stat = chart_stat_sop(p_ewma, chart_choice)

#   for i in 1:runs

#     # Fill data with i.i.d data 
#     rand!(dist, data)

#     # Add noise when using random count data
#     if dist isa DiscreteUnivariateDistribution
#       for j in 1:size(data, 2)
#         for i in 1:size(data, 1)
#           data[i, j] = data[i, j] + rand()
#         end
#       end
#     end

#     # dist as in SACF functions!
#     sop_frequencies!(m, n, lookup_array_sop, data, sop, win, sop_freq)

#     @views p_hat[1] = sum(sop_freq[[1, 3, 8, 11, 14, 17, 22, 24]])
#     @views p_hat[2] = sum(sop_freq[[2, 5, 7, 9, 16, 18, 20, 23]])
#     @views p_hat[3] = sum(sop_freq[[4, 6, 10, 12, 13, 15, 19, 21]])
#     p_hat ./= m * n # Divide each element of p_hat by m*n

#     @. p_ewma = (1 - lam) * p_ewma + lam * p_hat

#     stat = chart_stat_sop(p_ewma, chart_choice)
#     vals[i] = abs(stat)

#     fill!(win, 0)
#     fill!(sop_freq, 0)
#   end

#   quantile_val = quantile(vals, p_quantile)
#   return_vec = (vals, quantile_val)

#   return return_vec
# end


# # Function to get sensible starting values for the control limit
# function init_vals_sop(m, n, lam, chart_choice, dist, runs, p_quantile)

#   # Pre-allocate
#   lookup_array_sop = compute_lookup_array_sop()
#   sop_freq = zeros(24)
#   win = zeros(Int, 4)
#   data = zeros(m + 1, n + 1)
#   p_ewma = zeros(3)
#   p_hat = zeros(3)
#   vals = zeros(runs)
#   sop = zeros(4)

#   fill!(p_ewma, 1.0 / 3.0)
#   stat = chart_stat_sop(p_ewma, chart_choice)

#   for i in 1:runs

#     # Fill data with i.i.d data 
#     rand!(dist, data)

#     # Add noise when using random count data
#     if dist isa DiscreteUnivariateDistribution
#       for j in 1:size(data, 2)
#         for i in 1:size(data, 1)
#           data[i, j] = data[i, j] + rand()
#         end
#       end
#     end

#     # dist as in SACF functions!
#     sop_frequencies!(m, n, lookup_array_sop, data, sop, win, sop_freq)

#     @views p_hat[1] = sum(sop_freq[[1, 3, 8, 11, 14, 17, 22, 24]])
#     @views p_hat[2] = sum(sop_freq[[2, 5, 7, 9, 16, 18, 20, 23]])
#     @views p_hat[3] = sum(sop_freq[[4, 6, 10, 12, 13, 15, 19, 21]])
#     p_hat ./= m * n # Divide each element of p_hat by m*n

#     @. p_ewma = (1 - lam) * p_ewma + lam * p_hat

#     stat = chart_stat_sop(p_ewma, chart_choice)
#     vals[i] = abs(stat)

#     fill!(win, 0)
#     fill!(sop_freq, 0)
#   end

#   quantile_val = quantile(vals, p_quantile)
#   return_vec = (vals, quantile_val)

#   return return_vec
# end



# function compute_p_array_single_core(data::Array{T,3}, d1::Int, d2::Int; chart_choice=3) where {T<:Real}

#   # pre-allocate    
#   m = size(data, 1) - d1
#   n = size(data, 2) - d2
#   lookup_array_sop = compute_lookup_array_sop()
#   p_mat = zeros(size(data, 3), 3)
#   p_hat = zeros(1, 3)
#   sop = zeros(4)
#   sop_freq = zeros(Int, 24)
#   win = zeros(Int, 4)

#   # indices for sum of frequencies
#   index_sop = create_index_sop()
#   s_1 = index_sop[1]
#   s_2 = index_sop[2]
#   s_3 = index_sop[3]

#   # compute p_hat matrix
#   for i in axes(data, 3)

#     # Compute frequencies of sops
#     @views data_tmp = data[:, :, i]
#     sop_frequencies!(m, n, d1, d2, lookup_array_sop, data_tmp, sop, win, sop_freq)

#     # Compute sum of frequencies for each group
#     fill_p_hat!(p_hat, chart_choice, sop_freq, m, n, s_1, s_2, s_3)

#     p_mat[i, :] = p_hat

#     # Reset win and sop_freq
#     fill!(win, 0)
#     fill!(sop_freq, 0)
#     fill!(p_hat, 0)
#   end

#   return p_mat
# end

# function compute_p_array_bp_single_core(data::Array{T,3}, w::Int; chart_choice=3) where {T<:Real}

#   # pre-allocate
#   M_rows = size(data, 1)
#   N_cols = size(data, 2)
#   lookup_array_sop = compute_lookup_array_sop()
#   d1_d2_combinations = Iterators.product(1:w, 1:w)
#   p_array = zeros(size(data, 3), 3, length(d1_d2_combinations))
#   p_hat = zeros(1, 3)
#   sop = zeros(4)
#   sop_freq = zeros(Int, 24)
#   win = zeros(Int, 4)

#   # indices for sum of frequencies
#   index_sop = create_index_sop()
#   s_1 = index_sop[1]
#   s_2 = index_sop[2]
#   s_3 = index_sop[3]

#   # compute p_hat matrix
#   for i in axes(data, 3)

#     for (j, (d1, d2)) in enumerate(d1_d2_combinations)

#       m = M_rows - d1
#       n = N_cols - d2

#       # Compute frequencies of sops
#       @views data_tmp = data[:, :, i]
#       sop_frequencies!(m, n, d1, d2, lookup_array_sop, data_tmp, sop, win, sop_freq)

#       # Compute sum of frequencies for each group
#       fill_p_hat!(p_hat, chart_choice, sop_freq, m, n, s_1, s_2, s_3)

#       p_array[i, :, j] = p_hat

#       # Reset win and sop_freq
#       fill!(win, 0)
#       fill!(sop_freq, 0)
#       fill!(p_hat, 0)

#     end

#   end

#   return p_array
# end



# """
#     sop_frequencies(m::Int, n::Int, lookup_array_sop, data, sop)

# Compute the frequencies of the spatial ordinal patterns. 
# """
# function sop_frequencies(m::Int, n::Int, d1::Int, d2::Int, lookup_array_sop, data, sop)

#   # Creat matrices to fill     
#   sop_freqs = zeros(Int, 24)
#   win = zeros(Int, 4)

#   # Loop through data to fill sop vector
#   for j in 1:n
#     for i in 1:m

#       sop[1] = data[i, j]
#       sop[2] = data[i, j+d2]
#       sop[3] = data[i+d1, j]
#       sop[4] = data[i+d1, j+d2]

#       # Order 'sop_vec' in-place and save results in 'win'
#       order_vec!(sop, win)
#       # Get index for relevant pattern
#       ind2 = lookup_sop(lookup_array_sop, win)
#       # Add 1 to relevant pattern
#       sop_freqs[ind2] += 1
#     end
#   end

#   return sop_freqs

# end


# # Lookup function --> chooses the index of the sop
# function lookup_sop(lookup_array_sop, win)

#   return lookup_array_sop[win[1], win[2], win[3], win[4]]

# end

