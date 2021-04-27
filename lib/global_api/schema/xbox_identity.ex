defmodule GlobalApi.XboxIdentity do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:xuid, :integer, []}
  schema "xbox_identity" do
    field :gamertag, :string
    field :inserted_at, :integer
  end

  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [:xuid, :gamertag, :inserted_at])
    |> validate_required([:xuid, :gamertag, :inserted_at], message: "xbox identity is incomplete")
    |> unique_constraint([:xuid], name: "PRIMARY")
  end
end
