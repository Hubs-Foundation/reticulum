defmodule Ret.Sids do
  @num_random_bits_for_sid 16

  def generate_sid() do
    @num_random_bits_for_sid
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
    |> String.slice(0, 7)
    |> String.replace(~r/[_-]/, (:rand.uniform(10) - 1) |> Integer.to_string())
  end
end
