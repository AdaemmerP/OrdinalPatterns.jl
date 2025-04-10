
"""
  crit_val_sop(m, n, alpha, chart_choice, approximate::Bool)

Computes the critical value for the SOP test. Also allows the approximation of 
  the critical value. The input parameters are:

- `m::Int64`: The number of rows in the sop-matrix. Note that the data matrix has 
dimensions `M = m + d₁`, where `d₁` denotes the row delay.
- `n::Int64`: The number of columns in the sop-matrix. Note that the data matrix 
has dimensions `N = n + d₂`, where `d₂` denotes the column delay.
- `alpha::Float64`: The significance level.
- `chart_choice::Int64`: The choice of chart. 
- `approximate::Bool`: If `true`, the approximate critical value is computed. 
If `false`, the exact critical value is computed.

# Examples
```julia-repl
# compute approximate critical value for chart 1 
crit_val_sop(10, 10, 0.05, 1, true)
```
"""
function crit_val_sop(
  M, N, alpha, d1::Int, d2::Int; chart_choice, approximate::Bool=false
  )

  # sizes
  m = M - d1
  n = N - d2

  # check whether chart_choice is between 1 and 4
  @assert 1 <= chart_choice <= 4 "Wrong number for test statistic."

  # compute critical value based on approximation
  if approximate
    if chart_choice == 1
      term = sqrt(2 / 9 + 1 / 45)
      return (quantile(Normal(0, 1), 1 - alpha / 2) * term)

    elseif chart_choice == 2
      term = sqrt(2 / 3 + 1 / 9)
      return (quantile(Normal(0, 1), 1 - alpha / 2) * term)

    elseif chart_choice == 3
      term = sqrt(2 / 9 + 2 / 45)
      return (quantile(Normal(0, 1), 1 - alpha / 2) * term)

    elseif chart_choice == 4
      term = sqrt(2 / 3 + 2 / 45)
      return (quantile(Normal(0, 1), 1 - alpha / 2) * term)

    end

  # no approximation  
  else

    if chart_choice == 1
      term = sqrt(2 / 9 + 1 / 45 * (1 - 1 / (2 * m) - 1 / (2 * n)))
      return (quantile(Normal(0, 1), 1 - alpha / 2) * term)

    elseif chart_choice == 2
      term = sqrt(2 / 3 + 1 / 9 * (1 - 1 / (2 * m) - 1 / (2 * n)))
      return (quantile(Normal(0, 1), 1 - alpha / 2) * term)

    elseif chart_choice == 3
      term = sqrt(2 / 9 + 2 / 45 * (1 - 1 / (2 * m) - 1 / (2 * n)))
      return (quantile(Normal(0, 1), 1 - alpha / 2) * term)

    elseif chart_choice == 4
      term = sqrt(2 / 3 + 2 / 45 * (1 - 1 / (2 * m) - 1 / (2 * n)))
      return (quantile(Normal(0, 1), 1 - alpha / 2) * term) 
      
    end
  end
end


function test_sop(data, alpha, d1::Int, d2::Int; chart_choice, add_noise::Bool=false, approximate::Bool=false)

  # sizes
  M = size(data, 1)
  N = size(data, 2)
  m = M - d1
  n = N - d2

  # compute critical value
  crit_val = crit_val_sop(
    M, N, alpha, d1, d2; chart_choice=chart_choice, approximate=approximate
    )

  # compute test statistic
  test_stat = stat_sop(
    data, d1, d2;
    chart_choice=chart_choice, add_noise=add_noise
  )

  # return test result
  return (test_stat, crit_val, sqrt(m * n) * abs(test_stat) > crit_val)

end