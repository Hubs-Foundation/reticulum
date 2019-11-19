defmodule Ret.StorageUsed do
  use Cachex.Warmer
  use Retry

  def interval, do: :timer.minutes(5)

  def execute(_state) do
    storage_path = Application.get_env(:ret, Ret.Storage)[:storage_path]
    
    case System.cmd("df", ["--output=used", storage_path]) do
      { lines, 0 } ->
        used = lines |> String.split("\n") |> Enum.at(1) |> Integer.parse |> elem(0)
        {:ok, [{ :storage_used, used }]}
      { _fail, 1 } -> { :ok, [{ :storage_used, 0 }] }
    end
  end
end
