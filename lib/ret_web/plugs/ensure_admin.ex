defmodule RetWeb.Plugs.EnsureAdmin do
  import Plug.Conn

  def init([]), do: []

  def call(conn, []) do
    account = Guardian.Plug.current_resource(conn)

    if !account || !account.is_admin do
      conn
      |> send_resp(401, "")
      |> halt()
    else
      conn
    end
  end
end
