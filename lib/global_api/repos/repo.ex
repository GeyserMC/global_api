defmodule GlobalApi.Repo do
  use Ecto.Repo,
      otp_app: :global_api,
      adapter: Ecto.Adapters.MyXQL
end
