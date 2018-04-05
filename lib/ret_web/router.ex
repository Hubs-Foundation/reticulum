defmodule RetWeb.Router do
  use RetWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
  end

  pipeline :csrf_check do
    plug :protect_from_forgery
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug JaSerializer.Deserializer
  end

  pipeline :http_auth do
    plug BasicAuth, use_config: { :ret, :basic_auth }
  end

  scope "/health", RetWeb do
    get "/", HealthController, :index
  end

  scope "/api", RetWeb do
    scope "/v1", as: :api_v1 do
      resources "/hubs", Api.V1.HubController, only: [:show, :create, :update]
    end
  end

  scope "/", RetWeb do
    pipe_through [:browser, :csrf_check] ++ if (Mix.env == :prod), do: [:http_auth], else: []

    get "/*path", PageController, only: [:index]
  end
end
