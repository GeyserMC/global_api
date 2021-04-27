defmodule GlobalApi.UniqueSkin do
  use Ecto.Schema
  import Ecto.Changeset

  alias GlobalApi.Utils

  schema "unique_skins" do
    field :hash, :binary
    field :texture_id, :string
    field :value, :string
    field :signature, :string
    field :is_steve, :boolean
    field :inserted_at, :integer
  end

  def changeset(skin, attrs) do
    skin
    |> cast(attrs, [:hash, :texture_id, :value, :signature, :is_steve])
    |> validate_required([:hash, :texture_id, :value, :signature, :is_steve], message: "cannot add an incomplete skin")
    |> put_change(:inserted_at, :os.system_time(:millisecond))
  end

  def to_protected(%__MODULE__{} = unique_skin, %GlobalApi.PlayerSkin{} = player_skin),
      do: to_protected(unique_skin, GlobalApi.PlayerSkin.to_public(player_skin))

  def to_protected(%__MODULE__{} = unique_skin, player_skin) do
    %{
      hash: unique_skin.hash,
      texture_id: unique_skin.texture_id,
      value: unique_skin.value,
      signature: unique_skin.signature,
      is_steve: unique_skin.is_steve
    }
    |> Map.merge(player_skin)
  end

  def to_public(%__MODULE__{} = unique_skin, player_skin) do
    data = to_protected(unique_skin, player_skin)
    %{data | hash: Utils.hash_string(data.hash)}
  end
end
