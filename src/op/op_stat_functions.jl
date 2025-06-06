function chart_stat_op(p_vec, chart_choice)

  # Verify that chart_choice is between 1 and 6
  @assert 1 <= chart_choice <= 7 "Wrong number for test statistic."

  value = 0

  if length(p_vec) == 2

    if chart_choice == 4
      # β-chart for op_length of 2 
      return p_vec[2] - p_vec[1]
    end
  end

  if chart_choice == 1
    # H-chart: Equation (3), page 342, Weiss and Testik (2023)
    for i in axes(p_vec, 1)
      p_vec[i] > 0 && (value -= p_vec[i] * log(p_vec[i])) # to avoid log(0)          
    end
    return value

  elseif chart_choice == 2
    # Hex-chart: Equation (3), page 342, Weiss and Testik (2023), Equation (15), page 6 in the paper      
    for i in axes(p_vec, 1)
      p_vec[i] < 1 && (value -= (1 - p_vec[i]) * log(1 - p_vec[i])) # to avoid log of negative value     
    end
    return value

  elseif chart_choice == 3
    # Δ-chart: Equation (3), page 342, Weiss and Testik (2023)
    op_length = length(p_vec)
    for i in axes(p_vec, 1)
      value += (p_vec[i] - 1 / op_length)^2
    end
    return value

  elseif chart_choice == 4
    # β-chart: Bandt (2019), equation (3)
    return p_vec[1] - p_vec[6]

  elseif chart_choice == 5
    # τ-chart: Bandt (2019), equation (4)
    return p_vec[1] + p_vec[6] - (1 / 3)

  elseif chart_choice == 6
    # γ-chart: Bandt (2019), equation (5)
    return p_vec[3] + p_vec[4] - p_vec[2] - p_vec[5]

  elseif chart_choice == 7
    # δ-chart: Bandt (2019), equation (6)
    return p_vec[2] + p_vec[3] - p_vec[4] - p_vec[5]
  end

end

# TODO: Write one function for sequential charts, using λ, 
# TODO: Write one function for one chart, without λ,    


# Function to chart statistic and relative frequencies of ordinal patterns
function stat_op(data; chart_choice, op_length::Int=3, d::Int=1)

  # create vector with unit range for indexing 
  #dindex_ranges = compute_dindex_op(data; op_length=op_length, d=d)

  # Compute lookup array and number of ops
  lookup_array_op = compute_lookup_array_op(op_length=op_length)
  op_length_fact = factorial(op_length)

  p_vec = Vector{Float64}(undef, op_length_fact)
  p_count = zeros(Int, op_length_fact)
  fill!(p_vec, 1 / op_length_fact)
  bin = Vector{Int64}(undef, op_length_fact)
  win = Vector{Int64}(undef, op_length)

  for range_start in 1:(length(data)-(op_length-1)*d) #for (i, j) in enumerate(dindex_ranges)

    # Reset binarization vector
    fill!(bin, 0)

    # create unit range for indexing data
    unit_range = range(range_start; step=d, length=op_length)
    
    x_long = view(data, unit_range)
    #x_long = view(data, j) 

    # compute ordinal pattern based on permutations    
    sortperm!(win, x_long)
    #order_vec!(x_long, win)

    # Binarization of ordinal pattern
    if op_length == 2
      bin[lookup_array_op[win[1], win[2]]] = 1
    elseif op_length == 3
      bin[lookup_array_op[win[1], win[2], win[3]]] = 1
    end

    @. p_count += bin

  end

  p_rel = p_count ./ sum(p_count) #length(dindex_ranges)
  stat = chart_stat_op(p_rel, chart_choice)
  return [stat, p_rel]

end



# Function to compute EWMA chart statistic
function stat_op(data, lam; chart_choice, op_length::Int=3, d::Int=1)
  #stat_op(data, lam, chart_choice; op_length::Int=3, d=1)

  # create vector with unit range for indexing 
  dindex_ranges = compute_dindex_op(data; op_length=op_length, d=d)

  # Compute lookup array and number of ops
  lookup_array_op = compute_lookup_array_op(op_length=op_length)
  op_length_fact = factorial(op_length)

  p_vec = Vector{Float64}(undef, op_length_fact)
  p_count = zeros(Int, op_length_fact)
  fill!(p_vec, 1 / op_length_fact)
  bin = Vector{Int64}(undef, op_length_fact)
  win = Vector{Int64}(undef, op_length)
  stats_all = Vector{Float64}(undef, length(dindex_ranges))

  for (i, j) in enumerate(dindex_ranges)

    # Reset binarization vector
    fill!(bin, 0)

    x_long = view(data, j) 

    # compute ordinal pattern based on permutations
    order_vec!(x_long, win)
    # Binarization of ordinal pattern
    if op_length == 2
      bin[lookup_array_op[win[1], win[2]]] = 1
    elseif op_length == 3
      bin[lookup_array_op[win[1], win[2], win[3]]] = 1
    end
    # Compute EWMA statistic for binarized ordinal pattern, Equation (5), page 342, Weiss and Testik (2023)
    @. p_vec = lam * bin + (1 - lam) * p_vec
    @. p_count += bin
    # statistic based on smoothed p-estimate
    stat = chart_stat_op(p_vec, chart_choice)
    # Save temporary test statistic
    stats_all[i] = stat
  end

  p_rel = p_count ./ sum(p_count) #length(dindex_ranges)
  return [stats_all, p_rel]

end

