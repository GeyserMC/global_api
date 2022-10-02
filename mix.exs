defmodule GlobalApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :global_api,
      version: "1.0.2",
      elixir: "~> 1.14",
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
      {:phoenix, "~> 1.6.13"},
      {:phoenix_live_reload, "~> 1.3.3", only: :dev},
      {:phoenix_live_view, "~> 0.18.1"},
      {:phoenix_live_dashboard, "~> 0.7.0"},
      {:phoenix_ecto, "~> 4.4.0"},
      {:ecto_sql, "~> 3.9.0"},
      {:myxql, "~> 0.6.3"},
      {:httpoison, "~> 1.8.2"},
      {:rustler, "~> 0.26"},
      {:jason, "~> 1.4.0"},
      {:plug_cowboy, "~> 2.5.2"},
      {:cachex, "~> 3.4.0"},
      {:prom_ex, "~> 1.7.1"},
      {:unplug, "~> 1.0.0"},
      {:cors_plug, "~> 3.0.3"},
      {:telemetry, "~> 1.0"},
      {:telemetry_metrics, "~> 0.6.1"},
      {:telemetry_metrics_statsd, "~> 0.6.2"},
      {:telemetry_poller, "~> 1.0"},
      {:sentry, "~> 8.0.6"},
      {:distillery, "~> 2.1", only: :prod, git: "https://github.com/planswell/distillery", branch: "otp-25"},
      {:open_api_spex, "~> 3.12"},
      {:esbuild, "~> 0.3", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.1", runtime: Mix.env() == :dev}
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
      setup: ["deps.get", "ecto.setup"],
      get_and_compile: ["deps.get", "compile"],
      start: ["setup", "phx.server"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet" , "test"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
