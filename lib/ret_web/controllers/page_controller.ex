defmodule RetWeb.PageController do
  use RetWeb, :controller
  alias Ret.{Repo, Hub, Scene}

  def call(conn, _params) do
    render_for_path(conn.request_path, conn)
  end

  def render_for_path("/", conn), do: conn |> render_page("index")

  def render_for_path("/scenes/" <> path, conn) do
    scene_sid =
      path
      |> String.split("/")
      |> Enum.at(0)

    scene = Scene |> Repo.get_by(scene_sid: scene_sid) |> Repo.preload([:screenshot_owned_file])
    scene_meta_tags = Phoenix.View.render_to_string(RetWeb.PageView, "scene-meta.html", scene: scene)

    chunks =
      chunks_for_page("scene")
      |> List.insert_at(1, scene_meta_tags)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, chunks)
  end

  def render_for_path("/link", conn), do: conn |> render_page("link")
  def render_for_path("/link/", conn), do: conn |> render_page("link")

  def render_for_path("/link/" <> hub_sid_and_slug, conn) do
    hub_sid = hub_sid_and_slug |> String.split("/") |> List.first()
    conn |> redirect_to_hub_sid(hub_sid)
  end

  def render_for_path("/spoke", conn), do: conn |> render_page("spoke")
  def render_for_path("/spoke/", conn), do: conn |> render_page("spoke")
  def render_for_path("/avatar-selector.html", conn), do: conn |> render_page("avatar-selector")

  def render_for_path(path, conn) do
    hub_sid =
      path
      |> String.split("/")
      |> Enum.at(1)

    hub = Hub |> Repo.get_by(hub_sid: hub_sid) |> Repo.preload(scene: [:screenshot_owned_file])
    hub_meta_tags = Phoenix.View.render_to_string(RetWeb.PageView, "hub-meta.html", hub: hub, scene: hub.scene)

    chunks =
      chunks_for_page("hub")
      |> List.insert_at(1, hub_meta_tags)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, chunks)
  end

  defp redirect_to_hub_sid(conn, hub_sid) do
    case Hub |> Repo.get_by(hub_sid: hub_sid) do
      %Hub{} = hub -> conn |> redirect(to: "/#{hub.hub_sid}/#{hub.slug}")
      _ -> conn |> send_resp(404, "")
    end
  end

  defp render_page(conn, page) do
    chunks = page |> chunks_for_page
    conn |> render_chunks(chunks)
  end

  defp chunks_for_page(page) do
    with {:ok, chunks} <- Cachex.get(:page_chunks, page) do
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
