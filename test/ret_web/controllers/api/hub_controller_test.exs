defmodule RetWeb.HubControllerTest do
  use RetWeb.ConnCase

  alias Ret.{Hub, Repo}

  test "anyone can create a hub", %{conn: conn} do
    %{"status" => "ok"} =
      conn
      |> create_hub("Test Hub")
      |> json_response(200)
  end

  @tag :authenticated
  test "hubs have owners when authenticated", %{conn: conn} do
    %{"hub_id" => hub_id} =
      conn
      |> create_hub("Test Hub")
      |> json_response(200)

    created_hub = Hub |> Repo.get_by(hub_sid: hub_id)

    assert created_hub.account_id == Ret.Account.account_for_email("test@mozilla.com").account_id
  end

  defp create_hub(conn, name) do
    req = conn |> api_v1_hub_path(:create, %{"hub" => %{name: name}})
    conn |> post(req)
  end
end
