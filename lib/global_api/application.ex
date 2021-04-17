defmodule GlobalApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Cachex.Spec

  def start(_type, _args) do
    children = [
      GlobalApi.PromEx,
      GlobalApi.SocketQueue,
      GlobalApi.SkinQueue,
      GlobalApi.SkinUploader,
      create_cache(:xuid_to_skin, 3), #temporarely lowered from 5 to 3 for testing
      create_cache(:hash_to_skin, 15), # skin hashes are static
      create_cache(:xuid_request_cache, 7),
      create_cache(:xbox_api, 60),
      create_cache(:get_xuid, 5),
      create_cache(:get_gamertag, 5),
      GlobalApi.XboxApi,
      create_cache(:java_link, 5),
      create_cache(:bedrock_link, 5),
      GlobalApi.Repo,
      GlobalApi.MetricJob,
      # Start the Endpoint (http/https)
      GlobalApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GlobalApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    GlobalApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp create_cache(name, expire_time) do
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
    Application.get_env(:global_api, :app)[atom]
  end
end
