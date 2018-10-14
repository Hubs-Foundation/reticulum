defmodule Ret.TestHelpers do
  alias Ret.{Storage, Account, Scene, Repo}

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

  def create_account(_) do
    {:ok, account: Account.account_for_email("test@mozilla.com")}
  end

  def create_owned_file(%{account: account}) do
    {:ok, owned_file: generate_temp_owned_file(account)}
  end

  def create_scene(%{account: account, owned_file: owned_file}) do
    {:ok, scene} =
      %Scene{}
      |> Scene.changeset(account, owned_file, owned_file, owned_file, %{
        name: "Test Scene",
        description: "Test Scene Description"
      })
      |> Repo.insert_or_update()

    {:ok, scene: scene}
  end

  def clear_all_stored_files do
    File.rm_rf(Application.get_env(:ret, Storage)[:storage_path])
  end
end
