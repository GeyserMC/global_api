defmodule GlobalApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :global_api,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
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
      {:phoenix, "~> 1.5.7"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.4"},
      {:myxql, ">= 0.4.4"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_dashboard, "~> 0.4"},
      {:httpoison, "~> 1.7"},
      {:rustler, "~> 0.22-rc"},
      {:jason, "~> 1.1"},
      {:plug_cowboy, "~> 2.3"},
      {:cachex, "~> 3.3"},
      {:prom_ex, "~> 1.1.1"},
      {:cors_plug, "~> 2.0"},
      {:unplug, "~> 0.2.1"}
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
