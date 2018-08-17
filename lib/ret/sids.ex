defmodule Ret.Sids do
  @num_random_bits_for_sid 16
  def generate_sid() do
    @num_random_bits_for_sid
    |> :crypto.strong_rand_bytes()
    |> Base.encode32()
    |> String.downcase()
    |> String.slice(0, 10)
  end
end
