defmodule GlobalApi.Schema.AuthDebug do
  use Ecto.Schema

  schema "auth_debug" do
    field :auth_data, :map
    field :client_data, :string
  end
end
