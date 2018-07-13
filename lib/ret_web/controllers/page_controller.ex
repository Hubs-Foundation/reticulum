defmodule RetWeb.PageController do
  use RetWeb, :controller
  alias Ret.{Repo, Hub}

  def call(conn, _params) do
    render_for_path(conn.request_path, conn)
  end

  def render_for_path("/", conn) do
    conn |> render_page("index")
  end

  def render_for_path("/link", conn) do
    conn |> render_page("link")
  end

  def render_for_path("/avatar-selector.html", conn) do
    conn |> render_page("avatar-selector")
  end

  def render_for_path(path, conn) do
    hub_sid =
      path
      |> String.split("/")
      |> Enum.at(1)

    hub = Hub |> Repo.get_by(hub_sid: hub_sid)
    hub_meta_tags = Phoenix.View.render_to_string(RetWeb.PageView, "hub-meta.html", hub: hub)

    chunks =
      conn
      |> chunks_for_page("hub")
      |> List.insert_at(1, hub_meta_tags)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, chunks)
  end

  defp with_page_prefix(page, conn) do
    if conn.host =~ "smoke" do
      "smoke-#{page}"
    else
      page
    end
  end

  defp render_page(conn, page) do
    chunks = conn |> chunks_for_page(page)
    conn |> render_chunks(chunks)
  end

  defp chunks_for_page(conn, page) do
    key = page |> with_page_prefix(conn)

    with {:ok, chunks} <- Cachex.get(:page_chunks, key) do
      chunks
    else
      _ -> nil
    end
  end

  defp render_chunks(conn, nil) do
    conn |> send_resp(404, "")
  end

  defp render_chunks(conn, chunks) do
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, chunks)
  end
end
