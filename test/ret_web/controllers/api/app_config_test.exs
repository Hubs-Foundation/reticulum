defmodule RetWeb.AppConfigControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{AppConfig, Repo}

  setup [:create_account]

  test "admins can create app configs", %{conn: conn} do
    %{"status" => "ok"} =
      conn
      |> Ret.TestHelpers.put_auth_header_for_account("test@mozilla.com")
      |> create_app_config("test_config", "true")
      |> json_response(200)
  end

  test "non-admins cannot create app configs", %{conn: conn} do
    %{status: 401} =
      conn
      |> Ret.TestHelpers.put_auth_header_for_account("test2@mozilla.com")
      |> create_app_config("test_config", "true")
  end

  defp create_app_config(conn, key, value) do
    req = conn |> api_v1_app_config_path(:create, %{"app_config" => %{key: key, value: value}})
    conn |> post(req)
  end
end
