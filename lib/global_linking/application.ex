defmodule GlobalLinking.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Cachex.Spec

  def start(_type, _args) do
    children = [
      create_cache(:texture_id_by_xuid, 5),
      create_cache(:texture_id_to_hash, 7),
      create_cache(:xuid_request_cache, 7),
      create_cache(:xbox_api, 60),
      create_cache(:get_xuid, 5),
      create_cache(:get_gamertag, 5),
      GlobalLinking.XboxApi,
      {
        MyXQL,
        hostname: get_env(:hostname),
        username: get_env(:username),
        password: get_env(:password),
        database: get_env(:database),
        pool_size: get_env(:pool_size),
        name: :myxql
      },
      create_cache(:java_link),
      create_cache(:bedrock_link),
      # Start the Endpoint (http/https)
      GlobalLinkingWeb.Endpoint
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

  defp create_cache(name, expire_time \\ 1) do
    Supervisor.child_spec(
      {
        Cachex,
        [
          name: name,
          expiration: expiration(default: :timer.minutes(expire_time))
        ]
      },
      id: name
    )
  end

  def get_env(atom) do
    Application.get_env(:global_linking, :app)[atom]
  end
end
