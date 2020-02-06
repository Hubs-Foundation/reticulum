defmodule RetWeb.Api.V1.AppConfigController do
  use RetWeb, :controller
  alias Ret.{AppConfig}

  def create(conn, app_config_json) do
    # We expect the request body to be a json object where the leaf nodes are the config values.
    account = Guardian.Plug.current_resource(conn)

    app_config_json
    |> AppConfig.collapse()
    |> Enum.each(fn {key, val} -> AppConfig.set_config_value(key, val, account) end)

    conn |> send_resp(200, "")
  end

  def index(conn, _params) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, AppConfig.get_config() |> Poison.encode!())
  end
end
