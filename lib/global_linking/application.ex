defmodule GlobalLinking.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Cachex.Spec

  def start(_type, _args) do
    children = [
      {
        MyXQL,
        hostname: get_env(:hostname),
        username: get_env(:username),
        password: get_env(:password),
        database: get_env(:database),
        name: :myxql,
        pool_size: 2
      },
      create_cache(:java_link),
      create_cache(:bedrock_link),
      # Start the PubSub system
      {Phoenix.PubSub, name: GlobalLinking.PubSub},
      # Start the Endpoint (http/https)
      GlobalLinkingWeb.Endpoint
      # Start a worker by calling: GlobalLinking.Worker.start_link(arg)
      # {GlobalLinking.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GlobalLinking.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    GlobalLinkingWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp create_cache(name) do
    Supervisor.child_spec(
      {Cachex,
        [
          name: name,
          expiration: expiration(default: :timer.minutes(1))
        ]
      },
      id: name
    )
  end

  def get_env(atom) do
    Application.get_env(:global_linking, :app)[atom]
  end
end
