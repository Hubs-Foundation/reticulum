defmodule Ret.Sids do
  @num_random_bits_for_sid 32

  def generate_sid() do
    @num_random_bits_for_sid
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64()
    |> String.replace(~r/[1IlO0_-]/, "")
    |> String.slice(0, 7)
  end
end
