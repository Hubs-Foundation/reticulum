defmodule RetWeb.PageController do
  use RetWeb, :controller
  alias Ret.{Repo, Hub, Scene, SceneListing, Avatar, AppConfig, OwnedFile, AvatarListing, PageOriginWarmer, Storage}
  alias Plug.Conn
  import Ret.ConnUtils

  def call(conn, _params) do
    assets_host = RetWeb.Endpoint.config(:assets_url)[:host]
    link_host = RetWeb.Endpoint.config(:link_url)[:host]

    cond do
      matches_host(conn, assets_host) ->
        render_asset(conn)

      matches_host(conn, link_host) ->
        case conn.request_path do
          "/" -> conn |> redirect(to: "/link")
          _ -> conn |> redirect(to: "/link#{conn.request_path}")
        end

      true ->
        case conn.request_path do
          "/http://" <> _ -> cors_proxy(conn)
          "/https://" <> _ -> cors_proxy(conn)
          _ -> render_for_path(conn.request_path, conn.query_params, conn)
        end
    end
  end

  defp render_scene_content(%t{} = scene, conn) when t in [Scene, SceneListing] do
    {app_config, app_config_script, app_config_csp} = generate_app_config()

    scene_meta_tags =
      Phoenix.View.render_to_string(RetWeb.PageView, "scene-meta.html",
        scene: scene,
        ret_meta: Ret.Meta.get_meta(include_repo: false),
        translations: app_config["translations"]["en"],
        app_config_script: {:safe, app_config_script}
      )

    chunks =
      chunks_for_page("scene.html", :hubs)
      |> List.insert_at(1, scene_meta_tags)

    conn
    |> append_csp("script-src", app_config_csp)
    |> put_hub_headers("scene")
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, chunks)
  end

  defp render_scene_content(nil, conn) do
    conn |> send_resp(404, "")
  end

  defp render_avatar_content(%t{} = avatar, conn) when t in [Avatar, AvatarListing] do
    {app_config, app_config_script, app_config_csp} = generate_app_config()

    avatar_meta_tags =
      Phoenix.View.render_to_string(RetWeb.PageView, "avatar-meta.html",
        avatar: avatar,
        ret_meta: Ret.Meta.get_meta(include_repo: false),
        translations: app_config["translations"]["en"],
        app_config_script: {:safe, app_config_script}
      )

    chunks =
      chunks_for_page("avatar.html", :hubs)
      |> List.insert_at(1, avatar_meta_tags)

    conn
    |> append_csp("script-src", app_config_csp)
    |> put_hub_headers("avatar")
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

  def render_for_path("/link", _params, conn), do: conn |> render_page("link.html", :hubs, "link-meta.html")
  def render_for_path("/link/", _params, conn), do: conn |> render_page("link.html", :hubs, "link-meta.html")

  def render_for_path("/link/" <> hub_identifier_and_slug, _params, conn) do
    hub_identifier = hub_identifier_and_slug |> String.split("/") |> List.first()
    conn |> redirect_to_hub_identifier(hub_identifier)
  end

  def render_for_path("/discord", _params, conn), do: conn |> render_page("discord.html")
  def render_for_path("/discord/", _params, conn), do: conn |> render_page("discord.html")

  def render_for_path("/spoke", _params, conn), do: conn |> render_page("index.html", :spoke, "spoke-index-meta.html")

  def render_for_path("/spoke/" <> _path, _params, conn),
    do: conn |> render_page("index.html", :spoke, "spoke-index-meta.html")

  def render_for_path("/whats-new", _params, conn),
    do: conn |> render_page("whats-new.html", :hubs, "whats-new-meta.html")

  def render_for_path("/whats-new/", _params, conn),
    do: conn |> render_page("whats-new.html", :hubs, "whats-new-meta.html")

  def render_for_path("/hub.service.js", _params, conn),
    do: conn |> render_asset("hub.service.js", :hubs, "hub.service-meta.js")

  def render_for_path("/hubs/schema.toml", _params, conn), do: conn |> render_asset("schema.toml")

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
      manifest =
        case Cachex.get(:assets, :manifest) do
          {:ok, nil} ->
            manifest =
              Phoenix.View.render_to_string(RetWeb.PageView, "manifest.webmanifest",
                root_url: RetWeb.Endpoint.url(),
                app_name: get_app_config_value("translations|en|app-name") || "",
                app_description:
                  (get_app_config_value("translations|en|app-description") || "") |> String.replace("\\n", " ")
              )

            unless module_config(:skip_cache) do
              Cachex.put(:assets, :manifest, manifest, ttl: :timer.seconds(15))
            end

            manifest

          {:ok, manifest} ->
            manifest
        end

      conn
      |> put_resp_header("content-type", "application/manifest+json")
      |> send_resp(200, manifest)
    else
      conn |> send_resp(404, "Not found.")
    end
  end

  def render_for_path("/favicon.ico", _params, conn) do
    conn
    |> respond_with_configurable_asset(:app_config_favicon, "images|favicon", "image/x-icon")
  end

  def render_for_path("/app-icon.png", _params, conn) do
    conn
    |> respond_with_configurable_asset(:app_config_app_icon, "images|app_icon", "image/png")
  end

  def render_for_path("/app-thumbnail.png", _params, conn) do
    conn
    |> respond_with_configurable_asset(:app_config_app_thumbnail, "images|app_thumbnail", "image/png")
  end

  def render_for_path("/admin", _params, conn), do: conn |> render_page("admin.html", :admin)

  def render_for_path("/robots.txt", _params, conn) do
    allow_crawlers = Application.get_env(:ret, RetWeb.Endpoint)[:allow_crawlers] || false
    robots_txt = Phoenix.View.render_to_string(RetWeb.PageView, "robots.txt", allow_crawlers: allow_crawlers)

    conn
    |> send_resp(200, robots_txt)
  end

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

  defp respond_with_configurable_asset(conn, cache_key, config_key, content_type) do
    asset =
      case Cachex.get(:assets, cache_key) do
        {:ok, nil} ->
          app_config = AppConfig |> Repo.get_by(key: config_key) |> Repo.preload(:owned_file)

          asset =
            with %AppConfig{owned_file: %OwnedFile{} = owned_file} <- app_config,
                 {:ok, _meta, stream} <- Storage.fetch(owned_file) do
              stream |> Enum.join("")
            else
              _ -> ""
            end

          unless module_config(:skip_cache) do
            Cachex.put(:assets, cache_key, asset, ttl: :timer.seconds(15))
          end

          asset

        {:ok, asset} ->
          asset
      end

    if asset === "" do
      conn
      |> send_resp(404, "")
    else
      conn
      |> put_resp_header("content-type", content_type)
      |> send_resp(200, asset)
    end
  end

  defp render_index(conn) do
    method = conn |> get_req_header("x-original-method") |> Enum.at(0)
    conn |> render_index(method)
  end

  defp render_index(conn, "HEAD") do
    conn
    |> put_hub_headers("hub")
    |> send_resp(200, "")
  end

  defp render_index(conn, _method) do
    {app_config, app_config_script, app_config_csp} = generate_app_config()

    index_meta_tags =
      Phoenix.View.render_to_string(
        RetWeb.PageView,
        "index-meta.html",
        root_url: RetWeb.Endpoint.url(),
        translations: app_config["translations"]["en"],
        app_config_script: {:safe, app_config_script}
      )

    chunks =
      chunks_for_page("index.html", :hubs)
      |> List.insert_at(1, index_meta_tags)

    conn
    |> append_csp("script-src", app_config_csp)
    |> put_hub_headers("hub")
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, chunks)
  end

  defp put_hub_headers(conn, entity_type) do
    conn
    |> put_resp_header(
      "hub-name",
      get_app_config_value("translations|en|app-full-name") || get_app_config_value("translations|en|app-name") || ""
    )
    |> put_resp_header(
      "hub-entity-type",
      entity_type
    )
  end

  defp get_app_config_value(key) do
    if module_config(:skip_cache) do
      AppConfig.get_config_value(key)
    else
      AppConfig.get_cached_config_value(key)
    end
  end

  defp append_csp(conn, directive, source) do
    csp_header = conn.resp_headers |> Enum.find(fn {key, _value} -> key == "content-security-policy" end)

    new_directive = "#{directive} #{source}"

    csp_value =
      case csp_header do
        nil ->
          new_directive

        {_csp, csp_value} ->
          if csp_value |> String.contains?(directive) do
            csp_value |> String.replace(directive, new_directive)
          else
            "#{csp_value}; #{new_directive};"
          end
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

    {app_config, app_config_script, app_config_csp} = generate_app_config()

    {_, available_integrations_script, available_integrations_csp} =
      Ret.Meta.available_integrations_meta() |> generate_config("AVAILABLE_INTEGRATIONS")

    hub_meta_tags =
      Phoenix.View.render_to_string(RetWeb.PageView, "hub-meta.html",
        hub: hub,
        scene: hub.scene,
        ret_meta: Ret.Meta.get_meta(include_repo: false),
        available_integrations_script: {:safe, available_integrations_script},
        translations: app_config["translations"]["en"],
        app_config_script: {:safe, app_config_script}
      )

    chunks =
      chunks_for_page("hub.html", :hubs)
      |> List.insert_at(1, hub_meta_tags)

    conn
    |> append_csp("script-src", app_config_csp)
    |> append_csp("script-src", available_integrations_csp)
    |> put_hub_headers("room")
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, chunks)
  end

  def generate_app_config() do
    Ret.AppConfig.get_config(!!module_config(:skip_cache)) |> generate_config("APP_CONFIG")
  end

  defp generate_config(config, name) do
    config_json = config |> Poison.encode!()
    config_script = "window.#{name} = JSON.parse('#{config_json |> String.replace("'", "\\'")}')"

    config_csp = "'sha256-#{:crypto.hash(:sha256, config_script) |> :base64.encode()}'"

    {config, "<script>#{config_script}</script>", config_csp}
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

  defp render_asset(conn, asset, source \\ :hubs, meta_template \\ nil)

  defp render_asset(conn, nil, _source, _meta_template) do
    conn |> send_resp(404, "")
  end

  defp render_asset(conn, asset, source, meta_template) do
    app_config = Ret.AppConfig.get_config(!!module_config(:skip_cache))

    meta_content =
      if meta_template do
        Phoenix.View.render_to_string(RetWeb.PageView, meta_template, translations: app_config["translations"]["en"])
      else
        []
      end

    chunks =
      asset
      |> chunks_for_page(source)
      |> List.insert_at(1, meta_content)

    conn |> render_chunks(chunks, asset |> content_type_for_page)
  end

  defp render_page(conn, page, source \\ :hubs, meta_template \\ nil)

  defp render_page(conn, nil, _source, _meta_template) do
    conn |> send_resp(404, "")
  end

  defp render_page(conn, page, source, meta_template) do
    {app_config, app_config_script, app_config_csp} = generate_app_config()

    meta_tags =
      if meta_template do
        Phoenix.View.render_to_string(RetWeb.PageView, meta_template, translations: app_config["translations"]["en"])
      else
        []
      end

    chunks =
      page
      |> chunks_for_page(source)
      |> List.insert_at(1, app_config_script)
      |> List.insert_at(1, meta_tags)

    conn
    |> append_csp("script-src", app_config_csp)
    |> render_chunks(chunks, page |> content_type_for_page)
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
  defp content_type_for_page("schema.toml"), do: "text/plain"
  defp content_type_for_page(_), do: "text/html; charset=utf-8"

  defp render_chunks(conn, chunks, content_type) do
    conn
    |> put_resp_header("content-type", content_type)
    |> send_resp(200, chunks |> List.flatten() |> Enum.join("\n"))
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

  defp render_asset(conn) do
    static_options = Plug.Static.init(at: "/", from: module_config(:assets_path), gzip: true, brotli: true)
    Plug.Static.call(conn, static_options)
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
