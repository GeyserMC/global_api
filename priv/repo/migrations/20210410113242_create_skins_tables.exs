defmodule GlobalApi.Repo.Migrations.CreateSkinsTables do
  use Ecto.Migration

  def change do
    create table(:unique_skins) do
      add :hash, :binary, size: 32
      add :texture_id, :string, size: 64
      add :value, :string, size: 1000
      add :signature, :string, size: 1000
      add :is_steve, :bool
      add :inserted_at, :bigint
    end

    create table(:player_skins, primary_key: false) do
      add :bedrock_id, :bigint, primary_key: true
      add :skin_id, references(:unique_skins)

      timestamps(type: :bigint)
    end

    create(unique_index("unique_skins", [:hash, :is_steve], name: "unique_skin"))
  end
end
