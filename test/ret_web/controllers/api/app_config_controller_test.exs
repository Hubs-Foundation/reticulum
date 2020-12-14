defmodule RetWeb.AppConfigControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{AppConfig, Repo}

  setup [:create_account]

  test "admins can create app configs", %{conn: conn} do
    conn
    |> Ret.TestHelpers.put_auth_header_for_email("admin@mozilla.com")
    |> create_app_config(%{"test-config" => "foo"})
    |> response(200)

    %AppConfig{value: %{"value" => "foo"}} = AppConfig |> Repo.get_by(key: "test-config")
  end

  test "non-admins cannot create app configs", %{conn: conn} do
    %{status: 401} =
      conn
      |> Ret.TestHelpers.put_auth_header_for_email("test2@mozilla.com")
      |> create_app_config(%{"test-config" => "bar"})
  end

  defp create_app_config(conn, json) do
    req = conn |> api_v1_app_config_path(:create, json)
    conn |> post(req)
  end
end
