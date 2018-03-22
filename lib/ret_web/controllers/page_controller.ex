defmodule RetWeb.PageController do
  use RetWeb, :controller

  def index(conn, _params) do
    render_file(conn, "index.html")
  end

  def show(conn, _params) do
    render_file(conn, "hub.html")
  end

  defp render_file(conn, file) do
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> Plug.Conn.send_file(200, "priv/static/#{file}")
  end
end
