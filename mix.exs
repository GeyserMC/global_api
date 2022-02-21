defmodule GlobalApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :global_api,
      version: "1.0.1",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      build_embedded: Mix.env() == :prod,
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
      mod: {GlobalApi.Application, []},
      extra_applications: [
        :prom_ex,
        :logger,
        :runtime_tools,
        :ssl
      ]
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
      {:phoenix, "~> 1.6.6"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.7.2"},
      {:myxql, "~> 0.6.0"},
      {:phoenix_live_reload, "~> 1.3", only: :dev},
      {:phoenix_live_view, "~> 0.17.7"},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:httpoison, "~> 1.8"},
      {:rustler, "~> 0.23"},
      {:jason, "~> 1.3"},
      {:plug_cowboy, "~> 2.5"},
      {:cachex, "~> 3.4"},
      {:prom_ex, "~> 1.6.0"},
      {:cors_plug, "~> 2.0.3"},
      {:telemetry, "~> 1.0.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:sentry, "~> 8.0"},
      {:distillery, "~> 2.1", only: :prod},
      {:open_api_spex, "~> 3.11"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet" , "test"]
    ]
  end
end
