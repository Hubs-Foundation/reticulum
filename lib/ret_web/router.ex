defmodule RetWeb.Router do
  use RetWeb, :router
  use Plug.ErrorHandler
  use Sentry.Plug
  import Phoenix.LiveDashboard.Router

  pipeline :secure_headers do
    plug(:put_secure_browser_headers)
    plug(RetWeb.Plugs.AddCSP)
  end

  pipeline :ssl_only do
    plug(Plug.SSL, hsts: true, rewrite_on: [:x_forwarded_proto])
  end

  pipeline :parsed_body do
    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Phoenix.json_library(),
      length: 157_286_400,
      read_timeout: 300_000
    )
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:put_layout, false)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :public_api_access do
    plug(RetWeb.Plugs.RequirePublicApiAccess)
  end

  pipeline :proxy_api do
    plug(:accepts, ["json"])
    plug(RetWeb.Plugs.RewriteAuthorizationHeaderToPerms)
  end

  pipeline :auth_optional do
    plug(RetWeb.Guardian.AuthOptionalPipeline)
  end

  pipeline :forbid_disabled_accounts do
    plug(RetWeb.Plugs.ForbidDisabledAccounts)
  end

  pipeline :auth_required do
    plug(RetWeb.Guardian.AuthPipeline)
    plug(RetWeb.Canary.AuthorizationPipeline)
    plug(RetWeb.Plugs.ForbidDisabledAccounts)
  end

  pipeline :admin_required do
    plug(RetWeb.Guardian.AuthPipeline)
    plug(RetWeb.Plugs.AdminOnly)
    plug(RetWeb.Plugs.ForbidDisabledAccounts)
  end

  pipeline :bot_header_auth do
    plug(RetWeb.Plugs.BotHeaderAuthorization)
  end

  pipeline :canonicalize_domain do
    plug(RetWeb.Plugs.RedirectToMainDomain)
  end

  pipeline :graphql do
    plug RetWeb.ApiTokenAuthPipeline
    plug RetWeb.AddAbsintheContext
  end

  scope "/health", RetWeb do
    get("/", HealthController, :index)
  end

  scope "/api/postgrest" do
    pipe_through([:secure_headers, :auth_required, :admin_required, :proxy_api])
    forward("/", RetWeb.Plugs.PostgrestProxy)
  end

  scope "/api/ita" do
    pipe_through([:secure_headers, :auth_required, :admin_required, :proxy_api])
    forward("/", RetWeb.Plugs.ItaProxy)
  end

  scope "/", RetWeb do
    pipe_through(
      [:secure_headers, :parsed_body, :browser] ++
        if(Mix.env() == :prod, do: [:ssl_only, :canonicalize_domain], else: [])
    )

    post("/api/v1/accounts/expire_cookie", Api.V1.AccountController, :expire_cookie)

    scope "/" do
      pipe_through([:admin_required])

      # TODO: investigate whether we have pg_stat_statements installed for postgres
      # https://www.postgresql.org/docs/current/pgstatstatements.html
      # https://hexdocs.pm/phoenix_live_dashboard/ecto_stats.html#install-custom-extensions
      live_dashboard "/telemetry", metrics: RetWeb.Telemetry, ecto_repos: [Ret.Repo]
      post("/api/v1/accounts/set_cookie", Api.V1.AccountController, :set_cookie)
    end
  end

  scope "/api", RetWeb do
    pipe_through(
      [:secure_headers, :parsed_body, :api] ++ if(Mix.env() == :prod, do: [:ssl_only, :canonicalize_domain], else: [])
    )

    scope "/v1", as: :api_v1 do
      get("/meta", Api.V1.MetaController, :show)
      get("/avatars/:id/base.gltf", Api.V1.AvatarController, :show_base_gltf)
      get("/avatars/:id/avatar.gltf", Api.V1.AvatarController, :show_avatar_gltf)
      get("/oauth/:type", Api.V1.OAuthController, :show)

      scope "/support" do
        resources("/subscriptions", Api.V1.SupportSubscriptionController, only: [:create, :delete])
        resources("/availability", Api.V1.SupportSubscriptionController, only: [:index])
      end

      resources("/ret_notices", Api.V1.RetNoticeController, only: [:create])
    end

    scope "/v1", as: :api_v1 do
      resources("/slack", Api.V1.SlackController, only: [:create])
    end

    scope "/v1", as: :api_v1 do
      pipe_through([:bot_header_auth])
      resources("/hub_bindings", Api.V1.HubBindingController, only: [:create])
    end

    scope "/v1", as: :api_v1 do
      pipe_through([:auth_optional, :forbid_disabled_accounts])
      resources("/hubs", Api.V1.HubController, only: [:create, :delete])
    end

    scope "/v1", as: :api_v1 do
      pipe_through([:auth_optional])
      resources("/media/search", Api.V1.MediaSearchController, only: [:index])
      resources("/avatars", Api.V1.AvatarController, only: [:show])
      resources("/scenes", Api.V1.SceneController, only: [:show])
    end

    scope "/v1", as: :api_v1 do
      pipe_through([:auth_required])
      resources("/scenes", Api.V1.SceneController, only: [:create, :update])
      resources("/avatars", Api.V1.AvatarController, only: [:create, :update, :delete])
      resources("/hubs", Api.V1.HubController, only: [:update])
      resources("/assets", Api.V1.AssetsController, only: [:create, :delete])
      post("/twitter/tweets", Api.V1.TwitterController, :tweets)

      resources("/projects", Api.V1.ProjectController, only: [:index, :show, :create, :update, :delete]) do
        post("/publish", Api.V1.ProjectController, :publish)
        resources("/assets", Api.V1.ProjectAssetsController, only: [:index, :create, :delete])
      end
    end

    scope "/v1", as: :api_v1 do
      pipe_through([:admin_required])
      resources("/app_configs", Api.V1.AppConfigController, only: [:index, :create])
      resources("/accounts", Api.V1.AccountController, only: [:create])
      patch("/accounts", Api.V1.AccountController, :update)
      resources("/accounts/search", Api.V1.AccountSearchController, only: [:create])
    end
  end

  scope "/api/v2_alpha", RetWeb do
    pipe_through(
      [:secure_headers, :parsed_body, :api, :public_api_access, :auth_required] ++
        if(Mix.env() == :prod, do: [:ssl_only, :canonicalize_domain], else: [])
    )

    resources("/credentials", Api.V2.CredentialsController, only: [:create, :index, :update, :show])
  end

  scope "/api/v2_alpha", as: :api_v2_alpha do
    pipe_through(
      [:parsed_body, :api, :public_api_access, :graphql] ++ if(Mix.env() == :prod, do: [:ssl_only], else: [])
    )

    forward "/graphiql", Absinthe.Plug.GraphiQL, json_codec: Jason, schema: RetWeb.Schema
    forward "/", Absinthe.Plug, json_codec: Jason, schema: RetWeb.Schema
  end

  # Directly accessible APIs.
  # Permit direct file uploads without intermediate ALB/Cloudfront/CDN proxying.
  scope "/api", RetWeb do
    pipe_through([:secure_headers, :parsed_body, :api] ++ if(Mix.env() == :prod, do: [:ssl_only], else: []))

    scope "/v1", as: :api_v1 do
      resources("/media", Api.V1.MediaController, only: [:create])
    end
  end

  scope "/", RetWeb do
    pipe_through([:secure_headers, :parsed_body, :browser] ++ if(Mix.env() == :prod, do: [:ssl_only], else: []))

    head("/files/:id", FileController, :head)
    get("/files/:id", FileController, :show)
  end

  scope "/", RetWeb do
    pipe_through(
      [:secure_headers, :parsed_body, :browser] ++
        if(Mix.env() == :prod, do: [:ssl_only, :canonicalize_domain], else: [])
    )

    get("/*path", PageController, only: [:index])
  end
end
