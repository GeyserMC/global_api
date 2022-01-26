defmodule GlobalApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :global_api,
      version: "1.0.0",
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
      {:phoenix, "~> 1.5.9"},
      {:phoenix_ecto, "~> 4.3.0"},
      {:ecto_sql, "~> 3.6.2"},
      {:myxql, "~> 0.5.1"},
      {:phoenix_live_reload, "~> 1.3", only: :dev},
      {:phoenix_live_dashboard, "~> 0.5"},
      {:httpoison, "~> 1.8"},
      {:rustler, "~> 0.22.2"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:cachex, "~> 3.4"},
      {:prom_ex, "~> 1.3.0"},
      {:cors_plug, "~> 2.0.3"},
      {:unplug, "~> 0.2.1"},
      {:telemetry, "~> 0.4.3"},
      {:telemetry_metrics, "~> 0.6.1"},
      {:telemetry_metrics_statsd, "~> 0.6.0"},
      {:telemetry_poller, "~> 0.5.1"},
      {:sentry, "~> 8.0"},
      {:distillery, "~> 2.0", only: :prod}
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
