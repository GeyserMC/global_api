defmodule GlobalApi.Link do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:bedrock_id, :integer, []}
  schema "links" do
    field :java_id, :string
    field :java_name, :string

    timestamps(type: :integer, autogenerate: {:os,:system_time,[:millisecond]})
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [:bedrock_id, :java_id, :java_name])
    |> validate_required([:bedrock_id, :java_id, :java_name], message: "linked player has to have a Java UUID and username")
    |> put_change(:updated_at, :os.system_time(:millisecond))
  end

  def to_public(%__MODULE__{bedrock_id: bedrock_id, java_id: java_id, java_name: java_name, updated_at: updated_at}) do
    %{
      bedrock_id: bedrock_id,
      java_id: java_id,
      java_name: java_name,
      last_name_update: updated_at
    }
  end

  def to_public(_) do
    %{}
  end
end
