defmodule RetWeb.Plugs.AddCSP do
  @customizable_rule_types [
    :script_src,
    :font_src,
    :connect_src,
    :style_src,
    :img_src,
    :media_src,
    :frame_src,
    :child_src,
    :worker_src,
    :manifest_src,
    :form_action
  ]

  def init(default), do: default

  def call(conn, options) do
    strict = !!options[:strict]
    cache_key = %{type: :csp, strict: strict}

    csp =
      case Cachex.get(:assets, cache_key) do
        {:ok, nil} ->
          csp = generate_csp(strict: strict)
          Cachex.put(:assets, cache_key, csp, ttl: :timer.seconds(15))
          csp

        {:ok, csp} ->
          csp
      end

    conn_with_csp = conn |> Plug.Conn.put_resp_header("content-security-policy", csp)

    if strict do
      user_agent = conn |> Plug.Conn.get_req_header("user-agent") |> Enum.at(0, "")
      browser_is_ie = user_agent |> String.downcase() |> String.contains?("trident")

      if browser_is_ie do
        # IE11 doesn't respect modern CSP headers that contain newer CSP features, so we tack on
        # an older "x-..." header with a "sandbox" restriction that IE does respect.
        conn_with_csp |> Plug.Conn.put_resp_header("x-content-security-policy", "sandbox")
      else
        conn_with_csp
      end
    else
      conn_with_csp
    end
  end

  defp generate_csp(options) do
    csp_rules = generate_csp_rules(options)

    csp_rules
    |> Enum.map(fn {category, values} -> "#{category} #{values |> Enum.join(" ")}" end)
    |> Enum.join("; ")
  end

  defp generate_csp_rules(strict: true) do
    storage_url = Application.get_env(:ret, Ret.Storage)[:host]

    %{
      "default-src" => [
        "'none'"
      ],
      "img-src" => [
        "'self'",
        storage_url
      ],
      "style-src" => [
        "'self'",
        "'unsafe-inline'"
      ]
    }
  end

  defp generate_csp_rules(strict: false) do
    storage_url = Application.get_env(:ret, Ret.Storage)[:host]

    custom_rules = get_custom_rules()

    assets_url =
      if RetWeb.Endpoint.config(:assets_url)[:host] != "" do
        "https://#{RetWeb.Endpoint.config(:assets_url)[:host]}"
      else
        ""
      end

    cors_proxy_url = config_url(:cors_proxy_url)
    janus_port = Application.get_env(:ret, Ret.JanusLoadStatus)[:janus_port]
    default_janus_host = Application.get_env(:ret, Ret.JanusLoadStatus)[:default_janus_host]
    ret_host = Ret.Meta.get_meta(include_repo: false)[:phx_host]
    ret_domain = ret_host |> String.split(".") |> Enum.take(-2) |> Enum.join(".")
    ret_port = RetWeb.Endpoint.config(:url) |> Keyword.get(:port)
    is_subdomain = ret_host |> String.split(".") |> length > 2
    link_url = config_url(:link_url)
    # legacy
    thumbnail_url = config_url(:thumbnail_url) || cors_proxy_url |> String.replace("cors-proxy", "nearspark")

    # TODO: The https janus port CSP rules (including the default) can be removed after dialog is deployed,
    # since they are used to snoop and see what SFU it is.
    default_janus_csp_rule =
      if default_janus_host != nil && String.length(String.trim(default_janus_host)) > 0,
        do: "wss://#{default_janus_host}:#{janus_port} https://#{default_janus_host}:#{janus_port}",
        else: ""

    ret_direct_connect =
      if is_subdomain do
        "https://*.#{ret_domain}:#{ret_port} wss://*.#{ret_domain}:#{ret_port} wss://*.#{ret_domain}:#{janus_port} https://*.#{
          ret_domain
        }:#{janus_port} #{default_janus_csp_rule}"
      else
        "https://#{ret_host}:#{ret_port} wss://#{ret_host}:#{janus_port} wss://#{ret_host}:#{ret_port} https://#{
          ret_host
        }:#{janus_port} #{default_janus_csp_rule}"
      end

    %{
      "default-src" => [
        "'none'"
      ],
      "manifest-src" => [
        "'self'",
        custom_rules[:manifest_src]
      ],
      "script-src" => [
        "'self'",
        "blob:",
        "'sha256-/S6PM16MxkmUT7zJN2lkEKFgvXR7yL4Z8PCrRrFu4Q8='",
        "'sha256-MIpWPgYj31kCgSUFc0UwHGQrV87W6N5ozotqfxxQG0w='",
        "'sha256-ViVvpb0oYlPAp7R8ZLxlNI6rsf7E7oz8l1SgCIXgMvM='",
        "'sha256-buF6N8Z4p2PuaaeRUjm7mxBpPNf4XlCT9Fep83YabbM='",
        "'sha256-foB3G7vO68Ot8wctsG3OKBQ84ADKVinlnTg9/s93Ycs='",
        "'sha256-g0j42v3Wo/ohUAMR/t0EuObDSEkx1rZ3lv45fUaNmYs='",
        "'sha256-hsbRcgUBASABDq7qVGVTpbnWq/ns7B+ToTctZFJXYi8='",
        "'unsafe-eval'",
        "https://aframe.io",
        "https://cdn.jsdelivr.net/docsearch.js/1/docsearch.min.js",
        "https://s.ytimg.com",
        "https://ssl.google-analytics.com",
        "https://www.google-analytics.com",
        "https://www.youtube.com",
        assets_url,
        custom_rules[:script_src],
        storage_url
      ],
      "child-src" => [
        "'self'",
        "blob:",
        custom_rules[:child_src]
      ],
      "worker-src" => [
        "'self'",
        "blob:",
        assets_url,
        custom_rules[:worker_src],
        storage_url
      ],
      "font-src" => [
        "'self'",
        "https://cdn.aframe.io",
        "https://cdn.jsdelivr.net",
        "https://fonts.googleapis.com",
        "https://fonts.gstatic.com",
        assets_url,
        cors_proxy_url,
        custom_rules[:font_src],
        storage_url
      ],
      "style-src" => [
        "'self'",
        "'unsafe-inline'",
        "https://cdn.jsdelivr.net",
        "https://fonts.googleapis.com",
        assets_url,
        cors_proxy_url,
        custom_rules[:style_src],
        storage_url
      ],
      "connect-src" => [
        "'self'",
        "blob:",
        "data:",
        "https://api.github.com",
        "https://bh4d9od16a-3.algolianet.com",
        "https://cdn.aframe.io",
        "https://dpdb.webvr.rocks",
        "https://www.google-analytics.com",
        "https://www.youtube.com",
        "https://fonts.gstatic.com",
        assets_url,
        cors_proxy_url,
        custom_rules[:connect_src],
        link_url,
        ret_direct_connect,
        storage_url,
        thumbnail_url
      ],
      "img-src" => [
        "'self'",
        "blob:",
        "data:",
        "https://cdn.aframe.io",
        "https://cdn.jsdelivr.net",
        "https://user-images.githubusercontent.com",
        "https://www.google-analytics.com",
        "https://www.youtube.com",
        assets_url,
        cors_proxy_url,
        custom_rules[:img_src],
        storage_url,
        thumbnail_url
      ],
      "media-src" => [
        "'self'",
        "*.googlevideo.com",
        "blob:",
        "data:",
        "https://www.youtube.com",
        assets_url,
        cors_proxy_url,
        custom_rules[:media_src],
        storage_url,
        thumbnail_url
      ],
      "frame-src" => [
        "'self'",
        "https://docs.google.com",
        "https://player.vimeo.com",
        "https://www.youtube.com",
        custom_rules[:frame_src]
      ],
      "base-uri" => [
        "'none'"
      ],
      "form-action" => [
        "'self'",
        custom_rules[:form_action]
      ]
    }
  end

  defp get_custom_rules do
    @customizable_rule_types
    |> Enum.map(fn rule ->
      {rule, Application.get_env(:ret, __MODULE__)[rule] || ""}
    end)
    |> Map.new()
  end

  defp config_url(key) do
    url = RetWeb.Endpoint.config(key)

    if url && Keyword.get(url, :host) != "" do
      [scheme, host, port] = [:scheme, :host, :port] |> Enum.map(&Keyword.get(url, &1))

      port_string =
        if port do
          ":#{port}"
        else
          ""
        end

      "#{scheme || "https"}://#{host}#{port_string}"
    else
      nil
    end
  end
end
