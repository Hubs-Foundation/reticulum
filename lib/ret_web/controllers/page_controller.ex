defmodule RetWeb.PageController do
  use RetWeb, :controller

  def call(conn, _params) do
    render_for_path(conn.request_path, conn)
  end

  def render_for_path("/", conn) do
    render_file(conn, "index.html")
  end

  def render_for_path(_, conn) do
    render_file(conn, "hub.html")
  end

  defp render_file(conn, file) do
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> Plug.Conn.send_file(200, "#{Application.app_dir(:ret)}/priv/static/#{file}")
  end
end
