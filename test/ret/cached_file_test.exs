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
      aaa = cached_file("aaa")
      bbb = cached_file("bbb")
      ccc = cached_file("ccc")

      now = Timex.now()
      one_day_from_now = shift(%{now: now, shift_options: [days: 1]})
      one_week_from_now = shift(%{now: now, shift_options: [weeks: 1]})
      three_weeks_from_now = shift(%{now: now, shift_options: [weeks: 3]})

      Storage.fetch(aaa)
      Storage.fetch_at(bbb, one_day_from_now)
      Storage.fetch_at(ccc, three_weeks_from_now)

      CachedFile.vacuum(%{expiration: one_week_from_now})

      # The CachedFile has been vacuumed
      assert cached_file("aaa") === nil
      assert cached_file("bbb") === nil
      assert %CachedFile{cache_key: "ccc"} = cached_file("ccc")

      # The underlying asset has been vacuumed
      assert {:error, :not_found} =
               Storage.fetch(aaa.file_uuid, aaa.file_key, Storage.cached_file_path())

      assert {:error, :not_found} =
               Storage.fetch(bbb.file_uuid, bbb.file_key, Storage.cached_file_path())

      assert {:ok, _meta, _stream} = Storage.fetch(ccc)
    end
  end

  test "CachedFiles are migrated from expiring storage to cached storage" do
    cache_key = "abc"

    %CachedFile{file_uuid: file_uuid, file_key: file_key} =
      cached_file = put_file_in_expiring_storage(cache_key, "abc")

    # This line ensures the file is stored in the expiring_file_path
    {:ok, _meta, _stream} = Storage.fetch(file_uuid, file_key, Storage.expiring_file_path())
    # This line ensures the file is NOT stored in the cached_file_path
    {:error, _} = Storage.fetch(file_uuid, file_key, Storage.cached_file_path())
    # This line causes the file to be copied to the cached_file_path
    {:ok, _meta, _stream} = Storage.fetch(cached_file)
    # This line ensures the file has been copied to the cached_file_path
    {:ok, _meta, _stream} = Storage.fetch(file_uuid, file_key, Storage.cached_file_path())
  end

  test "CachedFiles are migrated from expiring storage to cached storage only once" do
    cache_key = "foobarbaz"

    %CachedFile{file_uuid: file_uuid, file_key: file_key} =
      cached_file = put_file_in_expiring_storage(cache_key, "abc")

    # This line ensures the file is stored in the expiring_file_path
    {:ok, _meta, _stream} = Storage.fetch(file_uuid, file_key, Storage.expiring_file_path())
    # This line ensures the file is NOT stored in the cached_file_path
    {:error, _} = Storage.fetch(file_uuid, file_key, Storage.cached_file_path())

    # This ensures that nothing goes wrong if the file is contested
    1..100
    |> Enum.map(fn _ ->
      Task.async(fn -> Storage.fetch(cached_file) end)
    end)
    |> Enum.map(fn task ->
      Task.await(task)
    end)
    |> Enum.all?(fn
      {:ok, _meta, _stream} -> true
      _ -> false
    end)

    # This line ensures the file has been copied to the cached_file_path
    {:ok, _meta, _stream} = Storage.fetch(file_uuid, file_key, Storage.cached_file_path())
  end

  test "Vacuuming CachedFiles destroy underlying assets when they exist" do
    with {:ok, _} <- CachedFile.fetch("aaa", write_to_path("aaa")),
         {:ok, _} <- CachedFile.fetch("bbb", write_to_path("bbb")),
         {:ok, _} <- CachedFile.fetch("ccc", write_to_path("ccc")) do
      aaa = cached_file("aaa")
      bbb = cached_file("bbb")
      ccc = cached_file("ccc")
      expiring = put_file_in_expiring_storage("expiring", "expiring")

      now = Timex.now()
      one_week_from_now = shift(%{now: now, shift_options: [weeks: 1]})
      three_weeks_from_now = shift(%{now: now, shift_options: [weeks: 3]})
      Storage.fetch_at(ccc, three_weeks_from_now)

      {:ok, %{errors: [^expiring]}} = CachedFile.vacuum(%{expiration: one_week_from_now})

      # The CachedFile has been vacuumed
      assert cached_file("aaa") === nil
      assert cached_file("bbb") === nil
      assert cached_file("expiring") === nil
      assert %CachedFile{cache_key: "ccc"} = cached_file("ccc")

      # The underlying asset has been vacuumed
      assert {:error, :not_found} =
               Storage.fetch(aaa.file_uuid, aaa.file_key, Storage.cached_file_path())

      assert {:error, :not_found} =
               Storage.fetch(bbb.file_uuid, bbb.file_key, Storage.cached_file_path())

      assert {:error, :not_found} =
               Storage.fetch(expiring.file_uuid, expiring.file_key, Storage.cached_file_path())

      assert {:ok, _meta, _stream} = Storage.fetch(ccc)

      # The expiring file will exist until vacuumed independently
      assert {:ok, _meta, _stream} =
               Storage.fetch(expiring.file_uuid, expiring.file_key, Storage.expiring_file_path())
    end
  end

  defp put_file_in_expiring_storage(cache_key, contents) do
    {:ok, path} = Temp.path()
    file_key = SecureRandom.hex()
    {:ok, %{content_type: content_type}} = write_large_file_to_path(contents).(path)

    {:ok, file_uuid} =
      Storage.store(path, content_type, file_key, nil, Storage.expiring_file_path())

    File.rm_rf(path)

    {:ok, cached_file} =
      %CachedFile{}
      |> changeset(%{
        cache_key: cache_key,
        file_uuid: file_uuid,
        file_key: file_key,
        file_content_type: content_type,
        accessed_at: Timex.now() |> Timex.to_naive_datetime() |> NaiveDateTime.truncate(:second)
      })
      |> Repo.insert()

    cached_file
  end

  defp shift(%{now: now, shift_options: shift_options}) do
    now
    |> Timex.shift(shift_options)
    |> Timex.to_naive_datetime()
    |> NaiveDateTime.truncate(:second)
  end

  defp cached_file(cache_key) do
    Repo.one(from CachedFile, where: [cache_key: ^cache_key])
  end

  defp changeset(struct, params) do
    struct
    |> cast(params, [:cache_key, :file_uuid, :file_key, :file_content_type, :accessed_at])
    |> validate_required([:cache_key, :file_uuid, :file_key, :file_content_type, :accessed_at])
    |> unique_constraint(:cache_key)
  end

  # Writes a file that is ~10MB per character of the input string
  defp write_large_file_to_path(s) do
    long_string =
      1..10_000
      |> Enum.map(fn _ -> s end)
      |> Enum.join()

    fn path ->
      File.write(path, "{ data: \"", [:write])

      1..1000
      |> Enum.each(fn _ ->
        File.write(path, long_string, [:append])
      end)

      File.write(path, "\" }", [:append])

      {:ok, %{content_type: "application/json"}}
    end
  end

  defp write_to_path(s) do
    fn path ->
      File.write(path, "{ data: \"#{s}\" }")
      {:ok, %{content_type: "application/json"}}
    end
  end
end
