defmodule RetWeb.Router do
  use RetWeb, :router

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
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(JaSerializer.Deserializer)
  end

  pipeline :authenticated do
    plug(RetWeb.Guardian.AuthPipeline)
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
    pipe_through(
      [:secure_headers, :api] ++
        if(Mix.env() == :prod, do: [:ssl_only, :canonicalize_domain], else: [])
    )

    scope "/v1", as: :api_v1 do
      resources("/hubs", Api.V1.HubController, only: [:create, :delete])
      resources("/media", Api.V1.MediaController, only: [:create])
      resources("/scenes", Api.V1.SceneController, only: [:show])
    end

    scope "/v1", as: :api_v1 do
      pipe_through([:authenticated])
      resources("/scenes", Api.V1.SceneController, only: [:create])
    end
  end

  scope "/", RetWeb do
    pipe_through([:secure_headers, :browser] ++ if(Mix.env() == :prod, do: [:ssl_only], else: []))

    resources("/files", FileController, only: [:show])
  end

  scope "/", RetWeb do
    pipe_through(
      [:secure_headers, :browser] ++
        if(Mix.env() == :prod, do: [:ssl_only, :canonicalize_domain], else: [])
    )

    get("/*path", PageController, only: [:index])
  end
end
