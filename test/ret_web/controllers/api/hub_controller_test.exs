defmodule RetWeb.HubControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  test "anyone can create a hub", %{conn: conn} do
    %{"status" => "ok"} =
      conn
      |> create_hub("Test Hub")
      |> json_response(200)
  end

  @tag :authenticated
  test "only hub owners can update a hub name", %{conn: conn} do
    %{"hub_id" => hub_id} =
      conn
      |> create_hub("Test Hub")
      |> json_response(200)

    %{"status" => "ok"} =
      conn
      |> update_hub_name(hub_id, "Shiny Test Hub")
      |> json_response(200)

    second_account_conn =
      Phoenix.ConnTest.build_conn()
      |> put_auth_header_for_account("test_two@mozilla.com")

    %{"error" => _} =
      second_account_conn
      |> update_hub_name(hub_id, "Super Shiny Test Hub")
      |> json_response(403)
  end

  defp create_hub(conn, name) do
    req = conn |> api_v1_hub_path(:create, %{"hub" => %{name: name}})
    conn |> post(req)
  end

  defp update_hub_name(conn, hub_id, name) do
    req = conn |> api_v1_hub_path(:update, hub_id, %{"hub" => %{name: name}})
    conn |> patch(req)
  end
end
