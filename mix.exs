defmodule Ret.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ret,
      version: "0.0.1",
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
      extra_applications: [:runtime_tools]
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
      {:phoenix, "~> 1.3.0"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_ecto, "~> 3.3"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.10"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:ja_serializer, "~> 0.12.0"},
      {:distillery, "~> 1.5",
       runtime: false, github: "gfodor/distillery", branch: "feature/boot_opts"},
      {:conform, "~> 2.5"},
      {:peerage, "~> 1.0"},
      {:httpoison, "~> 1.2.0"},
      {:poison, "~> 3.1"},
      {:ecto_autoslug_field, "~> 0.3"},
      {:cors_plug, "~> 1.5"},
      {:basic_auth, "~> 2.2"},
      {:statix, "~> 1.1"},
      {:quantum, "~> 2.2"},
      {:credo, "~> 0.9.1", only: [:dev, :test], runtime: false},
      {:plug_attack, "~> 0.3"},
      {:ecto_enum, "~> 1.0"},
      {:secure_headers, git: "https://github.com/gfodor/secure_headers.git", branch: "master"},
      {:the_end, "~> 1.1.0"},
      {:cachex, "~> 3.0.2"},
      {:retry, "~> 0.10.0"},
      {:open_graph, "~> 0.0.3"},
      {:secure_random, "~> 0.5.1"},
      {:bamboo, "~> 1.0.0"},
      {:bamboo_smtp, "~> 1.5"},
      {:guardian, "~> 1.1"}
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
