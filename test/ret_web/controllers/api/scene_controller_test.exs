defmodule RetWeb.SceneControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Account, Scene, Repo}

  setup [:create_account, :create_owned_file]

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  test "scene show looks up by scene sid", %{conn: conn, account: account, owned_file: owned_file} do
    {:ok, scene} =
      %Scene{}
      |> Scene.changeset(account, owned_file, owned_file, owned_file, %{
        name: "Test Scene",
        description: "Test Scene Description"
      })
      |> Repo.insert_or_update()

    response = conn |> get(api_v1_scene_path(conn, :show, scene.scene_sid)) |> json_response(200)

    %{
      "scenes" => [
        %{"name" => scene_name, "description" => scene_description}
      ]
    } = response

    assert scene_name == "Test Scene"
    assert scene_description == "Test Scene Description"
  end

  defp create_account(_) do
    {:ok, account: Account.account_for_email("test@mozilla.com")}
  end

  defp create_owned_file(%{account: account}) do
    {:ok, owned_file: generate_temp_owned_file(account)}
  end
end
