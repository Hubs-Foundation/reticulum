defmodule RetWeb.Plugs.HeaderAuthorization do
  import Plug.Conn

  def init(default), do: default

  def call(conn, _default) do
    env = Application.get_env(:ret, __MODULE__)
    [header_name, expected_value] = [env[:header_name], env[:header_value]]

    case conn |> get_req_header(header_name) do
      [^expected_value] -> conn
      _ -> conn |> send_resp(401, "") |> halt()
    end
  end
end
