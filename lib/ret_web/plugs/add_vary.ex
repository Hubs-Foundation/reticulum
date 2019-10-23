defmodule RetWeb.Plugs.AddVary do
  def init(default), do: default

  def call(conn, _options) do
    conn |> Plug.Conn.put_resp_header("vary", "Origin")
  end
end
