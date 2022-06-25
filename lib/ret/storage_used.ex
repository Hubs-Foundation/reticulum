defmodule Ret.StorageUsed do
  use Cachex.Warmer
  use Retry
  require Logger
  alias Ret.{StorageStat}

  def interval do
    if System.get_env("TURKEY_MODE") do
      # `du` command takes longer set the interval for longer
      # TODO :timer.minutes(10)
      :timer.minutes(1)
    else
      # TODO :timer.minutes(5)
      :timer.minutes(1)
    end
  end

  def execute(_state) do
    storage_path = Application.get_env(:ret, Ret.Storage)[:storage_path]

    if System.get_env("TURKEY_MODE") do
      # Yes TURKEY_MODE use `du`
      case System.cmd("du", ["-s", storage_path]) do
        {line, 0} ->
          {units_int, _remainder_of_binary} = String.split(line, "\t") |> Enum.at(0) |> Integer.parse()

          # Remove mb coversion before PR
          mb = convert_du_units_into_mb(units_int)
          Logger.warn("Storage used is: #{mb}")

          StorageStat.save_storage_stat(units_int)

          # Does this have to match the same units as below?
          {:ok, [{:storage_used, units_int}]}

        {_fail, 1} ->
          {:ok, [{:storage_used, 0}]}
      end
    else
      # Not TURKEY_MODE
      case System.cmd("df", ["-k", storage_path]) do
        {lines, 0} ->
          line = lines |> String.split("\n") |> Enum.at(1)

          {:ok, [_FS, _kb, used, _Avail], _RestStr} = :io_lib.fread('~s~d~d~d', line |> to_charlist)

          # TODO REMOVE FROM HERE AFTER TESTING
          StorageStat.save_storage_stat(used)

          # TODO what units are these? same units of 512 bytes?
          {:ok, [{:storage_used, used}]}

        {_fail, 1} ->
          {:ok, [{:storage_used, 0}]}
      end
    end
  end

  @du_units_in_bytes 512
  # okay this is probably super wrong should be 1024
  @bytes_to_mb 1_000_000
  def convert_du_units_into_mb(storage_blocks) do
    storage_blocks * @du_units_in_bytes / @bytes_to_mb
  end
end
