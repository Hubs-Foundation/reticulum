use Mix.Config

import_config "prod.exs"

config :peerage, log_results: true, via: Peerage.Via.Dns,
  dns_name: "foo.bar",
  app_name: "foo"

config :sentry,
  environment_name: :turkey,
  json_library: Poison,
  included_environments: [:turkey],
  tags: %{
    env: "turkey"
  }
