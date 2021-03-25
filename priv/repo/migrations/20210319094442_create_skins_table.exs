defmodule GlobalApi.Repo.Migrations.CreateSkinsTable do
  use Ecto.Migration

  def change do
    create table(:skins, primary_key: false) do
      add :bedrock_id, :bigint, primary_key: true
      add :hash, :binary, size: 32
      add :texture_id, :string, size: 64
      add :value, :text
      add :signature, :text
      add :is_steve, :bool

      timestamps(type: :utc_datetime)
    end

    create(index("skins", [:bedrock_id, :hash, :is_steve], name: "player_skin"))
    create(index("skins", [:hash, :is_steve], name: "unique_skin"))

    # index bedrock_id,hash,is_steve is used in is_player_using_this
  end
end
