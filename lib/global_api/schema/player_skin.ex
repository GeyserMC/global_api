defmodule GlobalApi.PlayerSkin do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:bedrock_id, :integer, []}
  schema "player_skins" do
    belongs_to :skin, GlobalApi.UniqueSkin

    timestamps(type: :integer, autogenerate: {:os,:system_time,[:millisecond]})
  end

  def changeset(skin, attrs) do
    skin
    |> cast(attrs, [:bedrock_id, :skin_id])
    |> validate_required([:bedrock_id, :skin_id], message: "cannot add an incomplete skin")
    |> put_change(:updated_at, :os.system_time(:millisecond))
  end

  def to_public(%__MODULE__{} = skin) do
    %{last_update: skin.updated_at}
  end
end
