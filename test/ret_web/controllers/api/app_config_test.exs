defmodule RetWeb.AppConfigControllerTest do
  use RetWeb.ConnCase

  alias Ret.{AppConfig, Repo}

  @tag :authenticated
  test "admins can create app configs", %{conn: conn} do
    %{"status" => "ok"} =
      conn
      |> create_app_config("test_config", "true")
      |> json_response(200)
  end

  defp create_app_config(conn, key, value) do
    req = conn |> api_v1_app_config_path(:create, %{"app_config" => %{key: key, value: value}})
    conn |> post(req)
  end
end
