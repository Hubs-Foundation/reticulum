# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :ret, ecto_repos: [Ret.Repo]

config :phoenix, :format_encoders, "json-api": Poison

config :canary,
  repo: Ret.Repo,
  unauthorized_handler: {RetWeb.Canary.AuthorizationErrorHandler, :authorization_error}

config :mime, :types, %{
  "application/vnd.api+json" => ["json-api"],
  "model/gltf+json" => ["gltf"],
  "model/gltf-binary" => ["glb"],
  "application/vnd.spoke.scene" => ["spoke"]
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

config :ret, Ret.Repo,
  migration_source: "schema_migrations",
  after_connect: {Ret.Repo, :set_search_path, ["public, ret0"]},
  # Downloads from Sketchfab to file cache hold connections open
  ownership_timeout: 60_000,
  timeout: 60_000

config :peerage, log_results: false

config :statix, prefix: "ret"

config :ret, Ret.Scheduler,
  jobs: [
    {"0 10 * * *", {Ret.Storage, :vacuum, []}},
    {"5 10 * * *", {Ret.Storage, :demote_inactive_owned_files, []}},
    {"10 10 * * *", {Ret.LoginToken, :expire_stale, []}},
    {"15 10 * * *", {Ret.Hub, :vacuum_entry_codes, []}},
    {"20 10 * * *", {Ret.Hub, :vacuum_hosts, []}},
    {"25 10 * * *", {Ret.CachedFile, :vacuum, []}}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
