defmodule Ret.StorageTest do
  use Ret.DataCase

  alias Ret.{OwnedFile, Storage}

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  setup _context do
    %{temp_file: generate_temp_file("test"), temp_file_2: generate_temp_file("test2")}
  end

  test "store a file", %{temp_file: temp_file} do
    {:ok, uuid} = Storage.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")
    {:ok, %{"content_type" => content_type}, stream} = Storage.fetch(uuid, "secret")

    assert content_type == "text/plain"
    assert stream |> Enum.map(& &1) |> Enum.join() == "test"
  end

  test "bad key should fail fetch", %{temp_file: temp_file} do
    {:ok, uuid} = Storage.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")
    {result, message} = Storage.fetch(uuid, "secret2")

    assert result == :error
    assert message == :not_allowed
  end

  test "promote a stored file", %{temp_file: temp_file} do
    account = Ret.Repo.insert!(%Ret.Account{})

    {:ok, uuid} = Storage.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")
    {:ok, owned_file} = Storage.promote(uuid, "secret", account)
    result = Storage.fetch(owned_file)

    assert_fetch_result(result, "text/plain", "test")
  end

  test "should be able to re-promote without failure", %{temp_file: temp_file} do
    account = Ret.Repo.insert!(%Ret.Account{})

    {:ok, uuid} = Storage.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")
    {:ok, _owned_file} = Storage.promote(uuid, "secret", account)
    {:ok, owned_file} = Storage.promote(uuid, "secret", account)

    owned_file_id = owned_file.owned_file_id

    {:ok, %OwnedFile{owned_file_id: ^owned_file_id}} = Storage.promote(uuid, "secret", account)
  end

  test "should be able to promote multiple files", %{
    temp_file: temp_file,
    temp_file_2: temp_file_2
  } do
    account = Ret.Repo.insert!(%Ret.Account{})

    {:ok, uuid_1} = Storage.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")
    {:ok, uuid_2} = Storage.store(%Plug.Upload{path: temp_file_2}, "text/plain", "secret2")

    %{t1: {:ok, owned_file_t1}, t2: {:ok, owned_file_t2}} =
      Storage.promote(%{t1: {uuid_1, "secret"}, t2: {uuid_2, "secret2"}}, account)

    r1 = Storage.fetch(owned_file_t1)
    r2 = Storage.fetch(owned_file_t2)

    assert_fetch_result(r1, "text/plain", "test")
    assert_fetch_result(r2, "text/plain", "test2")
  end

  defp assert_fetch_result(result, expected_content_type, expected_content) do
    {:ok, %{"content_type" => content_type}, stream} = result

    assert content_type == expected_content_type
    assert stream |> Enum.map(& &1) |> Enum.join() == expected_content
  end

  defp generate_temp_file(contents) do
    {:ok, temp_path} = Temp.mkdir("stored-file-test")
    file_path = temp_path |> Path.join("test.txt")
    file_path |> File.write(contents)
    file_path
  end

  defp clear_all_stored_files do
    File.rm_rf(Application.get_env(:ret, Storage)[:storage_path])
  end
end
