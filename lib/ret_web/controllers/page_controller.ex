defmodule RetWeb.PageController do
  use RetWeb, :controller
  alias Ret.{Repo, Hub, Scene, SceneListing}

  def call(conn, _params) do
    render_for_path(conn.request_path, conn)
  end

  defp render_scene_content(%t{} = scene, conn) when t in [Scene, SceneListing] do
    scene_meta_tags = Phoenix.View.render_to_string(RetWeb.PageView, "scene-meta.html", scene: scene)

    chunks =
      chunks_for_page("scene.html", :hubs)
      |> List.insert_at(1, scene_meta_tags)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, chunks)
  end

  defp render_scene_content(nil, conn) do
    conn |> send_resp(404, "")
  end

  def render_for_path("/", conn), do: conn |> render_page("index.html")

  def render_for_path("/scenes/" <> path, conn) do
    path
    |> String.split("/")
    |> Enum.at(0)
    |> Scene.scene_or_scene_listing_by_sid()
    |> Repo.preload([:screenshot_owned_file])
    |> render_scene_content(conn)
  end

  def render_for_path("/link", conn), do: conn |> render_page("link.html")
  def render_for_path("/link/", conn), do: conn |> render_page("link.html")

  def render_for_path("/link/" <> hub_identifier_and_slug, conn) do
    hub_identifier = hub_identifier_and_slug |> String.split("/") |> List.first()
    conn |> redirect_to_hub_identifier(hub_identifier)
  end

  def render_for_path("/spoke", conn), do: conn |> render_page("spoke.html")
  def render_for_path("/spoke/", conn), do: conn |> render_page("spoke.html")

  def render_for_path("/spoke-dev", conn), do: conn |> render_page("index.html", :spoke)
  def render_for_path("/spoke-dev/", conn), do: conn |> render_page("index.html", :spoke)

  def render_for_path("/whats-new", conn), do: conn |> render_page("whats-new.html")
  def render_for_path("/whats-new/", conn), do: conn |> render_page("whats-new.html")

  def render_for_path("/avatar-selector.html", conn), do: conn |> render_page("avatar-selector.html")
  def render_for_path("/hub.service.js", conn), do: conn |> render_page("hub.service.js")

  def render_for_path("/admin", conn), do: conn |> render_page("admin.html")

  def render_for_path("/" <> path, conn) do
    [hub_sid | subresource] = path |> String.split("/")

    hub = Hub |> Repo.get_by(hub_sid: hub_sid)
    render_hub_content(conn, hub, subresource |> Enum.at(0))
  end

  def render_hub_content(conn, nil, _) do
    conn |> send_resp(404, "")
  end

  def render_hub_content(conn, hub, "objects.gltf") do
    room_gltf = Ret.RoomObject.gltf_for_hub_id(hub.hub_id) |> Poison.encode!()

    conn
    |> put_resp_header("content-type", "model/gltf+json; charset=utf-8")
    |> send_resp(200, room_gltf)
  end

  def render_hub_content(conn, hub, _slug) do
    hub = hub |> Repo.preload(scene: [:screenshot_owned_file])
    hub_meta_tags = Phoenix.View.render_to_string(RetWeb.PageView, "hub-meta.html", hub: hub, scene: hub.scene)

    chunks =
      chunks_for_page("hub.html", :hubs)
      |> List.insert_at(1, hub_meta_tags)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, chunks)
  end

  # Redirect to the specified hub identifier, which can be a sid or an entry code
  defp redirect_to_hub_identifier(conn, hub_identifier) do
    # Rate limit requests for redirects.
    :timer.sleep(500)

    hub = Repo.get_by(Hub, hub_sid: hub_identifier) || Hub.get_by_entry_code_string(hub_identifier)

    case hub do
      %Hub{} = hub -> conn |> redirect(to: "/#{hub.hub_sid}/#{hub.slug}")
      _ -> conn |> send_resp(404, "")
    end
  end

  defp render_page(conn, page, source \\ :hubs)

  defp render_page(conn, nil, _source) do
    conn |> send_resp(404, "")
  end

  defp render_page(conn, page, source) do
    chunks = page |> chunks_for_page(source)
    conn |> render_chunks(chunks, page |> content_type_for_page)
  end

  defp chunks_for_page(page, source) do
    with {:ok, chunks} <- Cachex.get(:page_chunks, {source, page}) do
      chunks
    else
      _ -> nil
    end
  end

  defp content_type_for_page("hub.service.js") do
    "application/javascript; charset=utf-8"
  end

  defp content_type_for_page(_) do
    "text/html; charset=utf-8"
  end

  defp render_chunks(conn, chunks, content_type) do
    conn
    |> put_resp_header("content-type", content_type)
    |> send_resp(200, chunks)
  end
end
