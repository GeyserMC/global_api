defmodule GlobalApi.Schema.SkinStorage do
  use Ecto.Schema

  schema "skin_storage" do
    field :hash, :binary
    field :skin, :string
    field :code, :integer
  end
end
