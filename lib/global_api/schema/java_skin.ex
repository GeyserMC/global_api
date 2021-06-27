defmodule GlobalApi.JavaSkin do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, []}
  schema "java_skins" do
    field :is_steve, :boolean
    field :value, :string
    field :signature, :string
  end

  def changeset(skin, attrs) do
    skin
    |> cast(attrs, [:value, :signature])
    |> validate_required([:value, :signature], message: "cannot add an incomplete skin")
  end
end
