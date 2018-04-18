defmodule RetWeb.Router do
  use RetWeb, :router

  asset_hosts =
    "https://assets-prod.reticulum.io https://smoke-assets-prod.reticulum.io https://assets-dev.reticulum.io https://smoke-assets-dev.reticulum.io"

  asset_bundle_hosts =
    "https://asset-bundles-prod.reticulum.io https://smoke-asset-bundles-prod.reticulum.io https://asset-bundles-dev.reticulum.io https://smoke-asset-bundles-dev.reticulum.io"

  websocket_hosts =
    "wss://prod.reticulum.com wss://smoke-prod.reticulum.io wss://dev.reticulum.io wss://smoke-dev.reticulum.io wss://prod-janus.reticulum.io wss://dev-janus.reticulum.io "

  secure_header_config = [
    content_security_policy:
      "default-src none; script-src 'self' #{asset_hosts} https://aframe.io 'unsafe-eval'; font-src 'self' https://fonts.googleapis.com https://fonts.gstatic.com https://cdn.aframe.io #{
        asset_hosts
      }; style-src 'self' https://fonts.googleapis.com #{asset_hosts} 'unsafe-inline'; connect-src 'self' #{
        websocket_hosts
      } #{asset_bundle_hosts} https://cdn.aframe.io data:; img-src 'self' #{asset_hosts} #{
        asset_bundle_hosts
      } https://cdn.aframe.io data: blob:; media-src 'self' #{asset_hosts} #{asset_bundle_hosts} data:; frame-src 'self';",
    x_content_type_options: "nosniff",
    x_frame_options: "sameorigin",
    x_xss_protection: "1; mode=block",
    x_download_options: "noopen",
    x_permitted_cross_domain_policies: "master-only",
    strict_transport_security: "max-age=631138519"
  ]

  pipeline :ssl_only do
    plug(Plug.SSL, hsts: true, rewrite_on: [:x_forwarded_proto])
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(SecureHeaders, secure_headers: [merge: Mix.env() == :dev, config: secure_header_config])
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(JaSerializer.Deserializer)
    plug(SecureHeaders, secure_headers: [merge: Mix.env() == :dev, config: secure_header_config])
  end

  pipeline :http_auth do
    plug(BasicAuth, use_config: {:ret, :basic_auth})
  end

  scope "/health", RetWeb do
    get("/", HealthController, :index)
  end

  scope "/api", RetWeb do
    pipe_through([:api] ++ if(Mix.env() == :prod, do: [:ssl_only], else: []))

    scope "/v1", as: :api_v1 do
      resources("/hubs", Api.V1.HubController, only: [:create])
    end
  end

  scope "/", RetWeb do
    pipe_through([:browser] ++ if(Mix.env() == :prod, do: [:ssl_only, :http_auth], else: []))

    get("/*path", PageController, only: [:index])
  end
end
