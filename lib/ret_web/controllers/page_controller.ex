defmodule RetWeb.PageController do
  use RetWeb, :controller
  alias Ret.{Repo, Hub, Scene, SceneListing, Avatar, AvatarListing, PageOriginWarmer}
  alias Plug.Conn

  def call(conn, _params) do
    case conn.request_path do
      "/http://" <> _ -> cors_proxy(conn)
      "/https://" <> _ -> cors_proxy(conn)
      _ -> render_for_path(conn.request_path, conn.query_params, conn)
    end
  end

  defp render_scene_content(%t{} = scene, conn) when t in [Scene, SceneListing] do
    scene_meta_tags =
      Phoenix.View.render_to_string(RetWeb.PageView, "scene-meta.html",
        scene: scene,
        ret_meta: Ret.Meta.get_meta(include_repo: false)
      )

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

  defp render_avatar_content(%t{} = avatar, conn) when t in [Avatar, AvatarListing] do
    avatar_meta_tags =
      Phoenix.View.render_to_string(RetWeb.PageView, "avatar-meta.html",
        avatar: avatar,
        ret_meta: Ret.Meta.get_meta(include_repo: false)
      )

    chunks =
      chunks_for_page("avatar.html", :hubs)
      |> List.insert_at(1, avatar_meta_tags)

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, chunks)
  end

  defp render_avatar_content(nil, conn) do
    conn |> send_resp(404, "")
  end

  def render_for_path("/", params, conn) do
    if !Enum.empty?(params) || Ret.Account.has_accounts?() do
      conn |> render_index
    else
      conn |> redirect(to: "/admin")
    end
  end

  def render_for_path("/scenes/" <> path, _params, conn) do
    path
    |> String.split("/")
    |> Enum.at(0)
    |> Scene.scene_or_scene_listing_by_sid()
    |> Repo.preload([:screenshot_owned_file])
    |> render_scene_content(conn)
  end

  def render_for_path("/avatars/" <> path, _params, conn) do
    path
    |> String.split("/")
    |> Enum.at(0)
    |> Avatar.avatar_or_avatar_listing_by_sid()
    |> Repo.preload([:thumbnail_owned_file])
    |> render_avatar_content(conn)
  end

  def render_for_path("/link", _params, conn), do: conn |> render_page("link.html")
  def render_for_path("/link/", _params, conn), do: conn |> render_page("link.html")

  def render_for_path("/link/" <> hub_identifier_and_slug, _params, conn) do
    hub_identifier = hub_identifier_and_slug |> String.split("/") |> List.first()
    conn |> redirect_to_hub_identifier(hub_identifier)
  end

  def render_for_path("/discord", _params, conn), do: conn |> render_page("discord.html")
  def render_for_path("/discord/", _params, conn), do: conn |> render_page("discord.html")

  def render_for_path("/spoke", _params, conn), do: conn |> render_page("index.html", :spoke)
  def render_for_path("/spoke/" <> _path, _params, conn), do: conn |> render_page("index.html", :spoke)

  def render_for_path("/whats-new", _params, conn), do: conn |> render_page("whats-new.html")
  def render_for_path("/whats-new/", _params, conn), do: conn |> render_page("whats-new.html")

  def render_for_path("/hub.service.js", _params, conn), do: conn |> render_page("hub.service.js")

  def render_for_path("/app-config-schema.toml", _params, conn),
    do: conn |> render_page("app-config-schema.toml", :hubs, true)

  def render_for_path("/manifest.webmanifest", _params, conn) do
    ua =
      conn
      |> Conn.get_req_header("user-agent")
      |> List.first()
      |> UAParser.parse()

    # For iOS, do not render the manifest since we don't want to trigger the PWA functionality,
    # since WebRTC doesn't work then.
    supports_pwa = ua.family != "Safari" && ua.family != "Mobile Safari"

    if supports_pwa do
      conn |> render_page("manifest.webmanifest")
    else
      conn |> send_resp(404, "Not found.")
    end
  end

  def render_for_path("/admin", _params, conn), do: conn |> render_page("admin.html", :admin)

  def render_for_path("/" <> path, params, conn) do
    embed_token = params["embed_token"]

    [hub_sid | subresource] = path |> String.split("/")

    hub = Hub |> Repo.get_by(hub_sid: hub_sid)

    if embed_token && hub.embed_token != embed_token do
      conn |> send_resp(404, "Invalid embed token.")
    else
      conn =
        if embed_token do
          # Allow iframe embedding
          conn |> delete_resp_header("x-frame-options")
        else
          conn
        end

      render_hub_content(conn, hub, subresource |> Enum.at(0))
    end
  end

  def render_index(conn) do
    app_config =
      if module_config(:skip_cache) do
        Ret.AppConfig.get_config()
      else
        {:ok, app_config} = Cachex.get(:app_config, :app_config)
        app_config
      end

    app_config_json = app_config |> Poison.encode!()
    app_config_script = "window.APP_CONFIG = JSON.parse('#{app_config_json |> String.replace("'", "\\'")}')"

    index_meta_tags =
      Phoenix.View.render_to_string(RetWeb.PageView, "index-meta.html",
        app_config_script: {:safe, "<script>#{app_config_script}</script>"}
      )

    chunks =
      chunks_for_page("index.html", :hubs)
      |> List.insert_at(1, index_meta_tags)

    app_config_csp = "'sha256-#{:crypto.hash(:sha256, app_config_script) |> :base64.encode()}'"

    conn
    |> append_csp("script-src", app_config_csp)
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, chunks)
  end

  defp append_csp(conn, directive, source) do
    csp_header = conn.resp_headers |> Enum.find(fn {key, _value} -> key == "content-security-policy" end)

    new_directive = "#{directive} #{source}"

    csp_value =
      case csp_header do
        nil -> new_directive
        {_csp, csp_value} -> csp_value |> String.replace(directive, new_directive)
      end

    conn |> put_resp_header("content-security-policy", csp_value)
  end

  def render_hub_content(conn, nil, _) do
    conn |> send_resp(404, "Invalid URL.")
  end

  def render_hub_content(conn, hub, "objects.gltf") do
    room_gltf = hub.hub_id |> Ret.RoomObject.gltf_for_hub_id() |> Poison.encode!()

    conn
    |> put_resp_header("content-type", "model/gltf+json; charset=utf-8")
    |> send_resp(200, room_gltf)
  end

  def render_hub_content(conn, hub, _slug) do
    hub = hub |> Repo.preload(scene: [:screenshot_owned_file], scene_listing: [:screenshot_owned_file])

    hub_meta_tags =
      Phoenix.View.render_to_string(RetWeb.PageView, "hub-meta.html",
        hub: hub,
        scene: hub.scene,
        ret_meta: Ret.Meta.get_meta(include_repo: false)
      )

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

  defp render_page(conn, page, source \\ :hubs, include_newlines \\ false)

  defp render_page(conn, nil, _source, _include_newlines) do
    conn |> send_resp(404, "")
  end

  defp render_page(conn, page, source, include_newlines) do
    chunks = page |> chunks_for_page(source)
    conn |> render_chunks(chunks, page |> content_type_for_page, include_newlines)
  end

  defp chunks_for_page(page, source) do
    res =
      if module_config(:skip_cache) do
        PageOriginWarmer.chunks_for_page(source, page)
      else
        Cachex.get(:page_chunks, {source, page})
      end

    with {:ok, chunks} <- res do
      chunks
    else
      _ -> nil
    end
  end

  defp content_type_for_page("hub.service.js"), do: "application/javascript; charset=utf-8"
  defp content_type_for_page("manifest.webmanifest"), do: "application/manifest+json"

  defp content_type_for_page(_) do
    "text/html; charset=utf-8"
  end

  defp render_chunks(conn, chunks, content_type, include_newlines) do
    resp =
      if include_newlines do
        chunks |> List.flatten() |> Enum.join("\n")
      else
        chunks
      end

    conn
    |> put_resp_header("content-type", content_type)
    |> send_resp(200, resp)
  end

  defp cors_proxy(%Conn{request_path: "/" <> url, query_string: ""} = conn), do: cors_proxy(conn, url)
  defp cors_proxy(%Conn{request_path: "/" <> url, query_string: qs} = conn), do: cors_proxy(conn, "#{url}?#{qs}")

  defp cors_proxy(conn, url) do
    cors_proxy_url = Application.get_env(:ret, RetWeb.Endpoint)[:cors_proxy_url]
    [cors_scheme, cors_port, cors_host] = [:scheme, :port, :host] |> Enum.map(&Keyword.get(cors_proxy_url, &1))

    # Disallow CORS proxying unless request was made to the cors proxy url
    if cors_scheme == Atom.to_string(conn.scheme) && cors_host == conn.host && cors_port == conn.port do
      allowed_origins = Application.get_env(:ret, RetWeb.Endpoint)[:allowed_origins] |> String.split(",")

      opts =
        ReverseProxyPlug.init(
          upstream: url,
          allowed_origins: allowed_origins,
          proxy_url: "#{cors_scheme}://#{cors_host}:#{cors_port}",
          client_options: [ssl: [{:versions, [:"tlsv1.2"]}]]
        )

      body = ReverseProxyPlug.read_body(conn)

      %Conn{}
      |> Map.merge(conn)
      # Need to strip path_info since proxy plug reads it
      |> Map.put(:path_info, [])
      # Some domains disallow access from improper Origins
      |> Conn.delete_req_header("origin")
      |> ReverseProxyPlug.request(body, opts)
      |> ReverseProxyPlug.response(conn, opts)
    else
      conn |> send_resp(401, "Bad request.")
    end
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
