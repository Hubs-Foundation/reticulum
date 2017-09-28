defmodule Ret.Plug.Session do
  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _) do
    user = Guardian.Plug.current_resource(conn)
    conn
    |> assign(:current_user, user)
  end
end