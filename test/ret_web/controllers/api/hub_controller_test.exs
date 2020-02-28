defmodule RetWeb.HubControllerTest do
  use RetWeb.ConnCase

  alias Ret.{Hub, Repo, AppConfig}

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

  defp create_hub(conn, name) do
    req = conn |> api_v1_hub_path(:create, %{"hub" => %{name: name}})
    conn |> post(req)
  end
end
