use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ret, RetWeb.Endpoint,
  http: [port: 4001],
  allowed_origins: ["*"],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :ret, Ret.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "admin",
  password: "admin",
  database: "ret_test",
  hostname: "localhost",
  template: "template0",
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox

config :secure_headers, SecureHeaders, secure_headers: []

config :ret, Ret.Guardian,
  issuer: "ret",
  secret_key: "47iqPEdWcfE7xRnyaxKDLt9OGEtkQG3SycHBEMOuT2qARmoESnhc76IgCUjaQIwX"
