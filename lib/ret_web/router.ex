defmodule RetWeb.Router do
  use RetWeb, :router

  pipeline :secure_headers do
    plug(SecureHeaders, secure_headers: [merge: true])
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
    end
  end

  scope "/", RetWeb do
    pipe_through([:secure_headers, :browser] ++ if(Mix.env() == :prod, do: [:ssl_only], else: []))

    resources("/uploads", UploadController, only: [:show])
  end

  scope "/", RetWeb do
    pipe_through(
      [:secure_headers, :browser] ++
        if(Mix.env() == :prod, do: [:ssl_only, :canonicalize_domain], else: [])
    )

    get("/*path", PageController, only: [:index])
  end
end
