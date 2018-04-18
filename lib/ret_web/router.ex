defmodule RetWeb.Router do
  use RetWeb, :router

  pipeline :ssl_only do
    plug(Plug.SSL, hsts: true, rewrite_on: [:x_forwarded_proto])
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(SecureHeaders, secure_headers: [merge: true])
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(JaSerializer.Deserializer)
    plug(SecureHeaders, secure_headers: [merge: true])
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
