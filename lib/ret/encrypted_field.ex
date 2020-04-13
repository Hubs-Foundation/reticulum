defmodule Ret.EncryptedField do
  use Ecto.Type
  alias Ret.Crypto

  def type, do: :binary
  def cast(value), do: {:ok, value |> to_string()}
  def dump(value), do: {:ok, value |> to_string |> Crypto.encrypt()}
  def load(value), do: {:ok, value |> Crypto.decrypt()}
end
