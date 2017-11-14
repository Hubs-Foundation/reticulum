# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :ret,
  ecto_repos: [Ret.Repo],
  basic_auth: [
    username: "test",
    password: "test",
    realm:    "Y'All Hands"
  ]

config :phoenix, :format_encoders, "json-api": Posion

config :mime, :types, %{
  "application/vnd.api+json" => ["json-api"]
}

# Configures the endpoint
config :ret, RetWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "txlMOtlaY5x3crvOCko4uV5PM29ul3zGo1oBGNO3cDXx+7GHLKqt0gR9qzgThxb5",
  render_errors: [view: RetWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Ret.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :ueberauth, Ueberauth,
  base_path: "/api/login",
  providers: [google: { Ueberauth.Strategy.Google, [] }]

# Ueberauth Strategy Config for Google oauth
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
  redirect_uri: System.get_env("GOOGLE_REDIRECT_URI")

# Guardian configuration
config :guardian, Guardian,
  issuer: "reticulum",
  ttl: { 30, :days },
  allowed_drift: 2000,
  verify_issuer: true, # optional
  secret_key: "JpWapNaJQ4HU1spmFCb5EyWxJAwKXiCl8677nd2GWYCurPYXYksMsHIV3J8zsYvN",
  serializer: Ret.GuardianSerializer

config :ret, Ret.Repo,
  migration_source: "schema_migrations",
  after_connect: { Ret.Repo, :set_search_path, ["public, ret0"] }

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
