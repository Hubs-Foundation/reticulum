defmodule RetWeb.Router do
  use RetWeb, :router
  use Plug.ErrorHandler
  use Sentry.Plug

  pipeline :secure_headers do
    plug(
      SecureHeaders,
      secure_headers: [
        config: [
          x_content_type_options: "nosniff",
          x_frame_options: "sameorigin",
          x_xss_protection: "1; mode=block",
          x_download_options: "noopen",
          x_permitted_cross_domain_policies: "master-only",
          strict_transport_security: "max-age=631138519"
        ],
        merge: true
      ]
    )
  end

  pipeline :ssl_only do
    plug(Plug.SSL, hsts: true, rewrite_on: [:x_forwarded_proto])
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:put_layout, false)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(JaSerializer.Deserializer)
  end

  pipeline :auth_optional do
    plug(RetWeb.Guardian.AuthOptionalPipeline)
  end

  pipeline :auth_required do
    plug(RetWeb.Guardian.AuthPipeline)
    plug(RetWeb.Canary.AuthorizationPipeline)
  end

  pipeline :bot_header_auth do
    plug(RetWeb.Plugs.BotHeaderAuthorization)
  end

  pipeline :canonicalize_domain do
    plug(RetWeb.Plugs.RedirectToMainDomain)
  end

  pipeline :http_auth do
    plug(BasicAuth, use_config: {:ret, :basic_auth})
  end

  scope "/health", RetWeb do
    get("/", HealthController, :index)
  end

  scope "/api", RetWeb do
    pipe_through([:secure_headers, :api] ++ if(Mix.env() == :prod, do: [:ssl_only, :canonicalize_domain], else: []))

    scope "/v1", as: :api_v1 do
      resources("/media", Api.V1.MediaController, only: [:create])
      resources("/media/search", Api.V1.MediaSearchController, only: [:index])
      resources("/scenes", Api.V1.SceneController, only: [:show])
      resources("/avatars", Api.V1.AvatarController, only: [:show])
      get("/avatars/:id/avatar.gltf", Api.V1.AvatarController, :show_gltf)
      get("/oauth/:type", Api.V1.OAuthController, :show)

      scope "/support" do
        resources("/subscriptions", Api.V1.SupportSubscriptionController, only: [:create, :delete])
        resources("/availability", Api.V1.SupportSubscriptionController, only: [:index])
      end
    end

    scope "/v1", as: :api_v1 do
      pipe_through([:bot_header_auth])
      post("/hub_bindings", Api.V1.HubBindingController, :create)
      delete("/hub_bindings", Api.V1.HubBindingController, :delete)
    end

    scope "/v1", as: :api_v1 do
      pipe_through([:auth_optional])
      resources("/hubs", Api.V1.HubController, only: [:create, :delete])
    end

    scope "/v1", as: :api_v1 do
      pipe_through([:auth_required])
      resources("/scenes", Api.V1.SceneController, only: [:create, :update])
      resources("/avatars", Api.V1.AvatarController, only: [:create, :update])
      resources("/hubs", Api.V1.HubController, only: [:update])
    end
  end

  scope "/", RetWeb do
    pipe_through([:secure_headers, :browser] ++ if(Mix.env() == :prod, do: [:ssl_only], else: []))

    resources("/files", FileController, only: [:show])
  end

  scope "/", RetWeb do
    pipe_through([:secure_headers, :browser] ++ if(Mix.env() == :prod, do: [:ssl_only, :canonicalize_domain], else: []))

    get("/*path", PageController, only: [:index])
  end
end
