defmodule Ret.StorageUsed do
  use Cachex.Warmer
  use Retry
  require Logger

  def interval do
    if System.get_env("TURKEY_MODE") do
      # `du` command takes longer set the interval for longer
      # TODO :timer.minutes(10)
      :timer.minutes(1)
    else
      :timer.minutes(5)
    end
  end

  @du_units_in_bytes 512
  @bytes_to_mb 1_000_000
  def execute(_state) do
    storage_path = Application.get_env(:ret, Ret.Storage)[:storage_path]
    Logger.warn("storage path is #{storage_path}")

    if System.get_env("TURKEY_MODE") do
      # Yes TURKEY_MODE use `du`
      case System.cmd("du", ["-s", storage_path]) do
        {line, 0} ->
          {units_int, _remainder_of_binary} = String.split(line, "\t") |> Enum.at(0) |> Integer.parse()
          mb = units_int * @du_units_in_bytes / @bytes_to_mb
          Logger.warn("Storage used is: #{mb}")

          {:ok, [{:storage_used, mb}]}

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
