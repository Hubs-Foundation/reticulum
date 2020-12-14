defmodule RetWeb.Plugs.RequirePublicApiAccess do
  import Plug.Conn

  def init([]), do: []

  def call(conn, []) do
    if Ret.AppConfig.get_config_bool("features|public_api_access") do
      conn
    else
      conn |> send_resp(404, "") |> halt()
    end
  end
end
