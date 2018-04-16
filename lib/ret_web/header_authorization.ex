defmodule RetWeb.Plugs.HeaderAuthorization do
  import Plug.Conn

  @header_name Application.get_env(:ret, __MODULE__)[:header_name]
  @header_value Application.get_env(:ret, __MODULE__)[:header_value]

  def init(default), do: default

  def call(conn, _default) do
    call_with_header_value(conn, conn |> get_req_header(@header_name))
  end

  defp call_with_header_value(conn, [@header_value]) do
    conn
  end

  defp call_with_header_value(conn, _) do
    conn |> send_resp(401, "") |> halt()
  end
end
