defmodule RetWeb.Plugs.AddCSP do
  def init(default), do: default

  def call(conn, _options) do
    config_csp = Application.get_env(:ret, RetWeb.Plugs.AddCSP)[:content_security_policy]

    csp = if config_csp && config_csp != "" do
      config_csp
    else
      case Cachex.get(:assets, :csp) do
        {:ok, nil} ->
          csp = conn |> generate_csp
          Cachex.put(:assets, :csp, csp, ttl: :timer.seconds(15))
          csp

        {:ok, csp} ->
          csp
      end
    end

    conn |> Plug.Conn.put_resp_header("content-security-policy", csp)
  end

  defp generate_csp(conn) do
    assets_url = Application.get_env(:ret, Ret.Storage)[:host]
    cors_proxy_url = config_url(:cors_proxy_url)
    janus_port = Application.get_env(:ret, Ret.JanusLoadStatus)[:janus_port]
    ret_host = Ret.Meta.get_meta(include_repo: false)[:phx_host]
    ret_domain = ret_host |> String.split(".") |> Enum.take(-2) |> Enum.join(".")
    is_subdomain = ret_host |> String.split(".") |> length > 2
    link_url = config_url(:link_url)
    thumbnail_url = config_url(:thumbnail_url)
                    || cors_proxy_url |> String.replace("cors-proxy", "nearspark") # legacy

    wss_connect = if is_subdomain do
      "wss://*.#{ret_domain} wss://*.#{ret_domain}:#{janus_port}"
    else
      "wss://#{ret_host}:#{janus_port} wss://#{ret_host}"
    end

    "default-src 'none'; manifest-src 'self'; script-src #{assets_url} 'self' 'sha256-ViVvpb0oYlPAp7R8ZLxlNI6rsf7E7oz8l1SgCIXgMvM=' 'sha256-hsbRcgUBASABDq7qVGVTpbnWq/ns7B+ToTctZFJXYi8=' 'sha256-MIpWPgYj31kCgSUFc0UwHGQrV87W6N5ozotqfxxQG0w=' 'sha256-buF6N8Z4p2PuaaeRUjm7mxBpPNf4XlCT9Fep83YabbM=' 'sha256-/S6PM16MxkmUT7zJN2lkEKFgvXR7yL4Z8PCrRrFu4Q8=' https://www.google-analytics.com #{assets_url} https://aframe.io https://www.youtube.com https://s.ytimg.com 'unsafe-eval'; prefetch-src 'self' #{assets_url}; child-src 'self' blob:; worker-src #{assets_url} 'self' blob:; font-src 'self' https://fonts.googleapis.com https://cdn.jsdelivr.net https://fonts.gstatic.com https://cdn.aframe.io #{assets_url} #{cors_proxy_url}; style-src 'self' https://fonts.googleapis.com https://cdn.jsdelivr.net #{cors_proxy_url} #{assets_url} 'unsafe-inline'; connect-src 'self' #{cors_proxy_url} #{assets_url} #{link_url} https://dpdb.webvr.rocks #{thumbnail_url} #{wss_connect} https://cdn.aframe.io https://www.youtube.com https://api.github.com data: blob:; img-src 'self' https://www.google-analytics.com #{assets_url} #{cors_proxy_url} #{thumbnail_url} https://cdn.aframe.io https://www.youtube.com https://user-images.githubusercontent.com https://cdn.jsdelivr.net data: blob:; media-src 'self' #{cors_proxy_url} #{assets_url} #{thumbnail_url} https://www.youtube.com *.googlevideo.com data: blob:; frame-src https://www.youtube.com https://docs.google.com 'self'; base-uri 'none'; form-action 'self';"
  end

  defp config_url(key) do
    url = RetWeb.Endpoint.config(key)

    if url do
      [ scheme, host, port ] = [:scheme, :host, :port] |> Enum.map(&Keyword.get(url, &1))
      port_string = if port do ":#{port}" else "" end
      "#{scheme || "https"}://#{host}#{port_string}"
    else
      nil
    end
  end
end
