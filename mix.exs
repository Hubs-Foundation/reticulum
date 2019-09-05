defmodule Ret.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ret,
      version: System.get_env("RELEASE_VERSION") || "1.0.0",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Ret.Application, []},
      extra_applications: [:runtime_tools, :canada]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.4.0"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_ecto, "~> 4.0"},
      {:plug, "~> 1.7"},
      {:ecto, "~> 3.1"},
      {:ecto_sql, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.13"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.17"},
      {:plug_cowboy, "~> 2.0"},
      {:ja_serializer, "~> 0.15"},
      {:distillery, "~> 2.0"},
      {:peerage, "~> 1.0"},
      {:httpoison, "~> 1.5"},
      {:poison, "~> 3.1"},
      {:ecto_autoslug_field, "~> 2.0"},
      {:cors_plug, "~> 2.0"},
      {:statix, "~> 1.2"},
      {:quantum, "~> 2.2.7"},
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:plug_attack, "~> 0.4"},
      {:ecto_enum, "~> 1.3"},
      {:the_end, "~> 1.1.0"},
      {:cachex, "~> 3.2"},
      {:retry, "~> 0.13"},
      {:open_graph, "~> 0.0.3"},
      {:secure_random, "~> 0.5"},
      {:bamboo, "~> 1.3"},
      {:bamboo_smtp, "~> 1.7"},
      {:guardian, "~> 1.2"},
      {:canary, "~> 1.1.1"},
      {:temp, "~> 0.4"},
      {:timex, "~> 3.6"},
      {:web_push_encryption, "~> 0.2"},
      {:sentry, "~> 6.0"},
      {:toml, "~> 0.5"},
      {:scrivener_ecto, "~> 2.0"},
      {:ua_parser, "~> 1.5"},
      {:download, git: "https://github.com/gfodor/download.git", branch: "reticulum/master"},
      {:oauther, "~> 1.1"},
      {:jason, "~> 1.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
