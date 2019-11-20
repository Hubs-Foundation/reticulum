defmodule Ret.StorageUsed do
  use Cachex.Warmer
  use Retry

  def interval, do: :timer.minutes(5)

  def execute(_state) do
    storage_path = Application.get_env(:ret, Ret.Storage)[:storage_path]

    case System.cmd("df", ["-k", "-T", storage_path]) do
      {lines, 0} ->
        line = lines |> String.split("\n") |> Enum.at(1)

        {:ok, [_FS, _FSType, _kb, used, _Avail, _Cap, _MntOn], _RestStr} =
          :io_lib.fread('~s~s~d~d~d~d~s', line |> to_charlist)

        {:ok, [{:storage_used, used}]}

      {_fail, 1} ->
        {:ok, [{:storage_used, 0}]}
    end
  end
end
