defmodule Ret.StoredFileTest do
  use Ret.DataCase

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  setup _context do
    %{temp_file: generate_temp_file()}
  end

  test "store a file", %{temp_file: temp_file} do
    {:ok, uuid} = Ret.StoredFiles.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")
    {:ok, %{"content_type" => content_type}, stream} = Ret.StoredFiles.fetch(uuid, "secret")

    assert content_type == "text/plain"
    assert stream |> Enum.map(& &1) |> Enum.join() == "test"
  end

  test "bad key should fail fetch", %{temp_file: temp_file} do
    {:ok, uuid} = Ret.StoredFiles.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")
    {result, message} = Ret.StoredFiles.fetch(uuid, "secret2")

    assert result == :error
    assert message == :not_allowed
  end

  test "promote a stored file", %{temp_file: temp_file} do
    account = Ret.Repo.insert!(%Ret.Account{})

    {:ok, uuid} = Ret.StoredFiles.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")
    {:ok, stored_file} = Ret.StoredFiles.promote(uuid, "secret", account)
    {:ok, %{"content_type" => content_type}, stream} = Ret.StoredFiles.fetch(stored_file)

    assert content_type == "text/plain"
    assert stream |> Enum.map(& &1) |> Enum.join() == "test"
  end

  defp generate_temp_file do
    {:ok, temp_path} = Temp.mkdir("stored-file-test")
    file_path = temp_path |> Path.join("test.txt")
    file_path |> File.write("test")
    file_path
  end

  defp clear_all_stored_files do
    File.rm_rf(Application.get_env(:ret, Ret.StoredFiles)[:storage_path])
  end
end
