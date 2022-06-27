defmodule Ret.StorageUsed do
  use Cachex.Warmer
  use Retry
  require Logger

  def interval do
    # `du` command takes longer set the interval for longer
    if System.get_env("TURKEY_MODE"), do: :timer.minutes(10), else: :timer.minutes(5)
  end

  @blocks_to_bytes 1024
  def execute(_state) do
    storage_path = Application.get_env(:ret, Ret.Storage)[:storage_path]

    if System.get_env("TURKEY_MODE") do
      # Yes TURKEY_MODE use `du`
      case System.cmd("du", ["-s", storage_path]) do
        {line, 0} ->
          {blocks, _remainder_of_binary} = String.split(line, "\t") |> Enum.at(0) |> Integer.parse()

          {:ok, [{:storage_used, blocks * @blocks_to_bytes}]}

        {_fail, 1} ->
          {:ok, [{:storage_used, 0}]}
      end
    else
      # Not TURKEY_MODE
      case System.cmd("df", ["-k", storage_path]) do
        {lines, 0} ->
          line = lines |> String.split("\n") |> Enum.at(1)

          {:ok, [_FS, _kb, used, _Avail], _RestStr} = :io_lib.fread('~s~d~d~d', line |> to_charlist)

          {:ok, [{:storage_used, used}]}

        {_fail, 1} ->
          {:ok, [{:storage_used, 0}]}
      end
    end
  end
end
