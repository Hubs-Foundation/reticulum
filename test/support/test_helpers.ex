defmodule Ret.TestHelpers do
  alias Ret.{Storage}

  def generate_temp_owned_file(account) do
    temp_file = generate_temp_file("test")
    {:ok, uuid} = Storage.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")
    {:ok, owned_file} = Storage.promote(uuid, "secret", account)
    owned_file
  end

  def generate_temp_file(contents) do
    {:ok, temp_path} = Temp.mkdir("stored-file-test")
    file_path = temp_path |> Path.join("test.txt")
    file_path |> File.write(contents)
    file_path
  end

  def clear_all_stored_files do
    File.rm_rf(Application.get_env(:ret, Storage)[:storage_path])
  end
end
