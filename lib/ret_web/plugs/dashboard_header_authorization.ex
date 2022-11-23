defmodule RetWeb.Plugs.DashboardHeaderAuthorization do
  import Plug.Conn
  @header_name "x-ret-dashboard-access-key"

  def init(default), do: default

  def call(conn, _default) do
    expected_value =
      Application.get_env(:ret, RetWeb.Plugs.DashboardHeaderAuthorization)[:dashboard_access_key]

    case conn |> get_req_header(@header_name) do
      [""] -> conn |> send_resp(401, "") |> halt()
      [^expected_value] -> conn
      _ -> conn |> send_resp(401, "") |> halt()
    end
  end
end
