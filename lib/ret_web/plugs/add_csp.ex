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

  def call(conn, _options) do
    csp =
      case Cachex.get(:assets, :csp) do
        {:ok, nil} ->
          csp = generate_csp()
          Cachex.put(:assets, :csp, csp, ttl: :timer.seconds(15))
          csp

        {:ok, csp} ->
          csp
      end

    conn |> Plug.Conn.put_resp_header("content-security-policy", csp)
  end

  def generate_csp() do
    custom_rules = get_custom_rules()

    assets_url =
      if RetWeb.Endpoint.config(:assets_url)[:host] != "" do
        "https://#{RetWeb.Endpoint.config(:assets_url)[:host]}"
      else
        ""
      end

    storage_url = Application.get_env(:ret, Ret.Storage)[:host]
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

    "default-src 'none'; manifest-src #{custom_rules[:manifest_src]} 'self'; script-src * 'unsafe-inline' 'unsafe-eval'; child-src #{
      custom_rules[:child_src]
    } 'self' blob:; worker-src #{custom_rules[:worker_src]} #{storage_url} #{assets_url} 'self' blob:; font-src #{
      custom_rules[:font_src]
    } 'self' https://fonts.googleapis.com https://cdn.jsdelivr.net https://fonts.gstatic.com https://cdn.aframe.io #{
      storage_url
    } #{assets_url} #{cors_proxy_url}; style-src #{custom_rules[:style_src]} 'self' https://fonts.googleapis.com https://cdn.jsdelivr.net #{
      cors_proxy_url
    } #{storage_url} #{assets_url} 'unsafe-inline'; connect-src #{custom_rules[:connect_src]} 'self' #{cors_proxy_url} #{
      storage_url
    } #{assets_url} #{link_url} https://dpdb.webvr.rocks #{thumbnail_url} #{ret_direct_connect} https://www.google-analytics.com https://cdn.aframe.io https://www.youtube.com https://api.github.com https://bh4d9od16a-3.algolianet.com data: blob:; img-src #{
      custom_rules[:img_src]
    } 'self' https://www.google-analytics.com #{storage_url} #{assets_url} #{cors_proxy_url} #{thumbnail_url} https://cdn.aframe.io https://www.youtube.com https://user-images.githubusercontent.com https://cdn.jsdelivr.net data: blob:; media-src #{
      custom_rules[:media_src]
    } 'self' #{cors_proxy_url} #{storage_url} #{assets_url} #{thumbnail_url} https://www.youtube.com *.googlevideo.com data: blob:; frame-src #{
      custom_rules[:frame_src]
    } https://www.youtube.com https://docs.google.com https://player.vimeo.com 'self'; base-uri 'none'; form-action #{
      custom_rules[:form_action]
    } 'self';"
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
