defmodule Ret.Repo.MigrationHelpers do
  @type month_int :: 1..12
  @type year_int :: non_neg_integer

  @spec next_month(year_int, month_int) :: %{y: year_int, m: month_int}
  def next_month(y, 12) when y >= 0,
    do: %{y: y + 1, m: 1}

  def next_month(y, m) when y >= 0 and m in 1..11,
    do: %{y: y, m: m + 1}
end
