defmodule GlobalApi.Skin do
  use Ecto.Schema
  import Ecto.Changeset

  alias GlobalApi.Utils

  @primary_key {:bedrock_id, :integer, []}
  schema "skins" do
    field :hash, :binary
    field :texture_id, :string
    field :value, :string
    field :signature, :string
    field :is_steve, :boolean

    timestamps(type: :utc_datetime)
  end

  def changeset(skin, attrs) do
    skin
    |> cast(attrs, [:bedrock_id, :hash, :texture_id, :value, :signature, :is_steve])
    |> validate_required([:bedrock_id, :hash, :texture_id, :value, :signature, :is_steve], message: "cannot add an incomplete skin")
  end

  def to_public(skin) do
    %{
      hash: Utils.hash_string(skin.hash),
      texture_id: skin.texture_id,
      value: skin.value,
      signature: skin.signature,
      is_steve: skin.is_steve,
      last_update: skin.updated_at
    }
  end
end
