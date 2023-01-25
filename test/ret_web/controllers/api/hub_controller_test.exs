defmodule RetWeb.HubControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Hub, Scene, Repo, AppConfig}

  setup [:create_account, :create_owned_file, :create_scene]

  test "anyone can create a hub", %{conn: conn} do
    %{"status" => "ok"} =
      conn
      |> create_hub("Test Hub")
      |> json_response(200)
  end

  test "non-admins can't create a hub when creation disabled", %{conn: conn} do
    AppConfig.set_config_value("features|disable_room_creation", true)

    conn
    |> create_hub("Test Hub")
    |> response(401)

    AppConfig.set_config_value("features|disable_room_creation", false)
  end

  test "disabled accounts cannot create a hub", %{conn: conn} do
    disabled_account = create_account("disabled_account")
    disabled_account |> Ecto.Changeset.change(state: :disabled) |> Ret.Repo.update!()

    conn
    |> put_auth_header_for_email("disabled_account@mozilla.com")
    |> create_hub("Test Hub")
    |> response(401)
  end

  @tag :authenticated
  test "hub is assigned a creator when authenticated", %{conn: conn} do
    %{"hub_id" => hub_id} =
      conn
      |> create_hub("Test Hub")
      |> json_response(200)

    created_hub = Hub |> Repo.get_by(hub_sid: hub_id) |> Repo.preload(:created_by_account)

    created_account = Ret.Account.account_for_email("test@mozilla.com")
    assert created_hub.created_by_account.account_id == created_account.account_id
  end

  test "anyone can assign user_data to a hub", %{conn: conn} do
    %{"hub_id" => hub_id} =
      conn
      |> create_hub_with_attrs(%{name: "Test Hub", user_data: %{test: "Hello World"}})
      |> json_response(200)

    created_hub = Hub |> Repo.get_by(hub_sid: hub_id)

    assert created_hub.user_data["test"] == "Hello World"
  end

  test "non-room owners can't update a hub", %{conn: conn} do
    %{"hub_id" => hub_id} =
      conn
      |> create_hub("Test Hub")
      |> json_response(200)

    conn
    |> update_hub(hub_id, %{name: "New Name"})
    |> response(401)
  end

  @tag :authenticated
  test "The room owner can update a hub", %{conn: conn} do
    %{"hub_id" => hub_id} =
      conn
      |> create_hub("Test Hub")
      |> json_response(200)

    %{"hubs" => hubs} =
      conn
      |> update_hub(hub_id, %{name: "New Name"})
      |> json_response(200)

    assert Enum.at(hubs, 0)["name"] === "New Name"
  end

  @tag :authenticated
  test "The room owner can change the scene of a hub", %{conn: conn} do
    %{"hub_id" => hub_id} =
      conn
      |> create_hub("Test Hub")
      |> json_response(200)

    hub = Hub |> Repo.get_by(hub_sid: hub_id) |> Repo.preload(:scene)

    assert is_nil(hub.scene_id)

    scene = Scene |> Repo.one()

    assert !is_nil(scene)

    %{"hubs" => hubs} =
      conn
      |> update_hub(hub_id, %{scene_id: scene.scene_sid})
      |> json_response(200)

    hub_response = Enum.at(hubs, 0)

    assert hub_response["scene"]["scene_id"] === scene.scene_sid
  end

  @tag :authenticated
  test "The room owner can change the member_permissions of a hub", %{conn: conn} do
    %{"hub_id" => hub_id} =
      conn
      |> create_hub_with_attrs(%{name: "Test Hub"})
      |> json_response(200)

    hub = Hub |> Repo.get_by(hub_sid: hub_id) |> Repo.preload(:scene)

    assert Hub.has_member_permission?(hub, :spawn_camera) === false
    assert Hub.has_member_permission?(hub, :spawn_and_move_media) === false
    assert Hub.has_member_permission?(hub, :pin_objects) === false

    %{"hubs" => hubs} =
      conn
      |> update_hub(hub_id, %{member_permissions: %{spawn_camera: true, pin_objects: true}})
      |> json_response(200)

    hub_response = Enum.at(hubs, 0)

    assert hub_response["member_permissions"]["spawn_camera"] === true
    assert hub_response["member_permissions"]["spawn_and_move_media"] === false
    assert hub_response["member_permissions"]["pin_objects"] === true

    %{"hubs" => hubs} =
      conn
      |> update_hub(hub_id, %{
        member_permissions: %{spawn_and_move_media: true, pin_objects: false}
      })
      |> json_response(200)

    hub_response = Enum.at(hubs, 0)

    assert hub_response["member_permissions"]["spawn_camera"] === true
    assert hub_response["member_permissions"]["spawn_and_move_media"] === true
    assert hub_response["member_permissions"]["pin_objects"] === false
  end

  @tag :authenticated
  test "The room owner can allow the promotion of a hub", %{conn: conn} do
    %{"hub_id" => hub_id} =
      conn
      |> create_hub("Test Hub")
      |> json_response(200)

    hub = Hub |> Repo.get_by(hub_sid: hub_id) |> Repo.preload(:scene)

    assert hub.allow_promotion === false

    AppConfig.set_config_value("features|public_rooms", true)

    %{"hubs" => hubs} =
      conn
      |> update_hub(hub_id, %{allow_promotion: true})
      |> json_response(200)

    hub_response = Enum.at(hubs, 0)

    assert hub_response["allow_promotion"] === true

    %{"hubs" => hubs} =
      conn
      |> update_hub(hub_id, %{allow_promotion: false})
      |> json_response(200)

    hub_response = Enum.at(hubs, 0)

    assert hub_response["allow_promotion"] === false

    AppConfig.set_config_value("features|public_rooms", false)
  end

  @tag :authenticated
  test "An error is returned of the scene cannot be found", %{conn: conn} do
    %{"hub_id" => hub_id} =
      conn
      |> create_hub("Test Hub")
      |> json_response(200)

    conn
    |> update_hub(hub_id, %{name: "New Name", scene_id: "badscene"})
    |> response(422)
  end

  defp create_hub(conn, name) do
    create_hub_with_attrs(conn, %{name: name})
  end

  defp create_hub_with_attrs(conn, attrs) do
    req = conn |> api_v1_hub_path(:create, %{"hub" => attrs})
    conn |> post(req)
  end

  defp update_hub(conn, hub_id, attrs) do
    body = Poison.encode!(%{"hub" => attrs})

    conn
    |> put_req_header("content-type", "application/json")
    |> patch(api_v1_hub_path(conn, :update, hub_id), body)
  end
end
