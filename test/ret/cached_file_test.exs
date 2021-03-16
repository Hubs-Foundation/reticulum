defmodule Ret.CachedFileTest do
  use Ret.DataCase
  import Ret.TestHelpers

  alias Ret.{CachedFile, Repo, Storage}

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  test "cache a file" do
    uri_cold =
      CachedFile.fetch("foo", fn path ->
        File.write(path, "test")
        {:ok, %{content_type: "application/json"}}
      end)

    uri_hot =
      CachedFile.fetch("foo", fn path ->
        File.write(path, "test2")
        {:ok, %{content_type: "application/json"}}
      end)

    assert uri_hot != nil
    assert uri_hot == uri_cold
    assert uri_cold |> elem(0) === :ok
  end

  test "vaccuum shouldn't fail" do
    CachedFile.vacuum()
  end

  test "CachedFiles are vacuumed based on access time" do
    with {:ok, _} <- CachedFile.fetch("aaa", write_to_path("aaa")),
         {:ok, _} <- CachedFile.fetch("bbb", write_to_path("bbb")),
         {:ok, _} <- CachedFile.fetch("ccc", write_to_path("ccc")) do
      aaa = cached_file(%{cache_key: "aaa"})
      bbb = cached_file(%{cache_key: "bbb"})
      ccc = cached_file(%{cache_key: "ccc"})

      now = Timex.now()
      one_day_from_now = shift(%{now: now, shift_options: [days: 1]})
      one_week_from_now = shift(%{now: now, shift_options: [weeks: 1]})
      three_weeks_from_now = shift(%{now: now, shift_options: [weeks: 3]})

      Storage.fetch(aaa)
      Storage.fetch_at(bbb, one_day_from_now)
      Storage.fetch_at(ccc, three_weeks_from_now)

      CachedFile.vacuum(%{expiration: one_week_from_now})

      # The CachedFile has been vacuumed
      assert cached_file(%{cache_key: "aaa"}) === nil
      assert cached_file(%{cache_key: "bbb"}) === nil
      assert %CachedFile{cache_key: "ccc"} = cached_file(%{cache_key: "ccc"})

      # The underlying asset has been vacuumed
      assert {:error, :not_allowed} = Storage.fetch(aaa)
      assert {:error, :not_allowed} = Storage.fetch(bbb)
      assert {:ok, _meta, _stream} = Storage.fetch(ccc)
    end
  end

  defp shift(%{now: now, shift_options: shift_options}) do
    now |> Timex.shift(shift_options) |> Timex.to_naive_datetime() |> NaiveDateTime.truncate(:second)
  end

  defp cached_file(%{cache_key: cache_key}) do
    CachedFile |> where(cache_key: ^cache_key) |> Repo.one()
  end

  defp write_to_path(s) do
    fn path ->
      File.write(path, "{ data: \"#{s}\" }")
      {:ok, %{content_type: "application/json"}}
    end
  end
end
