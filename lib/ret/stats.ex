defmodule Ret.Stats do
  # Given a keyword list of symbols to integer weights returns a value according to that distribution
  #
  # Eg weighted_sample(a: 1, b: 10) will sample according to a distribution where b is 10x more likely than a.
  def weighted_sample(value_to_weights) do
    sum = value_to_weights |> Keyword.values() |> Enum.sum()
    values_to_p = value_to_weights |> Enum.map(fn {value, weight} -> {value, weight / sum} end)
    weighted_sample(values_to_p, :rand.uniform())
  end

  defp weighted_sample([{value, _}], _), do: value
  defp weighted_sample([{value, p} | _], x) when x < p, do: value
  defp weighted_sample([{_, p} | t], x), do: weighted_sample(t, x - p)
  defp weighted_sample(_, _), do: nil
end
