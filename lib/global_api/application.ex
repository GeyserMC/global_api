defmodule GlobalApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Cachex.Spec

  def start(_type, _args) do
    children = [
      GlobalApi.PromEx,
      {GlobalApi.DatabaseQueue, [pool_size: 7]},
      GlobalApi.SocketQueue,
      GlobalApi.SkinPreQueue,
      GlobalApi.SkinPreUploader,
      GlobalApi.SkinUploadQueue,
      GlobalApi.SkinUploader,
      create_cache(:xuid_to_skin, 2),
      create_cache(:hash_to_skin, 15), # skin hashes are static
      create_cache(:xuid_request_cache, 7),
      create_cache(:general, 60 * 24 * 365),
      create_cache(:get_xuid, 15),
      create_cache(:get_gamertag, 15),
      create_cache(:link_token_cache, 15),
      create_cache(:recent_skin_uploads, 1),
      GlobalApi.XboxUtils,
      GlobalApi.IdentityUpdater,
      create_cache(:java_link, 5),
      create_cache(:bedrock_link, 5),
      GlobalApi.Repo,
      GlobalApi.Telemetry,
      # Start the Endpoint (http/https)
      GlobalApiWeb.Endpoint
    ]

    # enable PubSub when code reloading is enabled
    children =
      if Application.get_env(:global_api, GlobalApiWeb.Endpoint)[:code_reloader],
         do: children ++ [{Phoenix.PubSub, name: GlobalApi.PubSub}],
         else: children

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
