defmodule RetWeb.SceneControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Scene, Repo}

  setup [:create_account, :create_owned_file, :create_scene]

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  test "scene show looks up by scene sid", %{conn: conn, scene: scene} do
    response = conn |> get(api_v1_scene_path(conn, :show, scene.scene_sid)) |> json_response(200)

    %{
      "scenes" => [
        %{"name" => scene_name, "description" => scene_description}
      ]
    } = response

    assert scene_name == "Test Scene"
    assert scene_description == "Test Scene Description"
  end

  test "scene create 401's when not logged in", %{conn: conn, owned_file: owned_file} do
    params = scene_create_or_update_params(owned_file)
    conn |> post(api_v1_scene_path(conn, :create), params) |> response(401)
  end

  @tag :authenticated
  test "scene create works when logged in", %{conn: conn, owned_file: owned_file} do
    params = scene_create_or_update_params(owned_file)

    response = conn |> post(api_v1_scene_path(conn, :create), params) |> json_response(200)
    %{"scenes" => [%{"scene_id" => scene_id}]} = response

    created_scene = Scene |> Repo.get_by(scene_sid: scene_id)

    assert created_scene.name == "Name"
    assert created_scene.description == "Description"
  end

  @tag :authenticated
  test "scene update works when logged in", %{conn: conn, owned_file: owned_file, scene: scene} do
    params = scene_create_or_update_params(owned_file, "New Name", "New Description")

    conn |> patch(api_v1_scene_path(conn, :update, scene.scene_sid), params) |> json_response(200)
    updated_scene = Scene |> Repo.get_by(scene_sid: scene.scene_sid)

    assert updated_scene.name == "New Name"
    assert updated_scene.slug == "new-name"
    assert updated_scene.description == "New Description"
  end

  test "scene update disallowed for different user", %{
    conn: conn,
    owned_file: owned_file,
    scene: scene
  } do
    {:ok, token, _claims} =
      "test2@mozilla.com"
      |> Ret.Account.find_or_create_account_for_email()
      |> Ret.Guardian.encode_and_sign()

    conn = conn |> Plug.Conn.put_req_header("authorization", "bearer: " <> token)
    params = scene_create_or_update_params(owned_file, "New Name", "New Description")

    conn |> patch(api_v1_scene_path(conn, :update, scene.scene_sid), params) |> response(401)
  end

  defp scene_create_or_update_params(owned_file, name \\ "Name", description \\ "Description") do
    %{
      "scene" => %{
        "name" => name,
        "description" => description,
        "model_file_id" => owned_file.owned_file_uuid,
        "model_file_token" => owned_file.key,
        "screenshot_file_id" => owned_file.owned_file_uuid,
        "screenshot_file_token" => owned_file.key,
        "scene_file_id" => owned_file.owned_file_uuid,
        "scene_file_token" => owned_file.key
      }
    }
  end
end
