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

  scope "/", RetWeb do
    pipe_through [:browser, :csrf_check]

    get "/", PageController, :index
  end

  scope "/health", RetWeb do
    get "/", HealthController, :index
  end
end
