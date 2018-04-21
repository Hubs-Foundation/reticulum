defmodule RetWeb.Plugs.HeaderAuthorization do
  import Plug.Conn

  def init(default), do: default

  def call(conn, _default) do
    header_name = Application.get_env(:ret, __MODULE__)[:header_name]
    expected_header_value = Application.get_env(:ret, __MODULE__)[:header_value]

    case conn |> get_req_header(header_name) do
      [^expected_header_value] -> conn
      _ -> conn |> send_resp(401, "") |> halt()
    end
  end
end
