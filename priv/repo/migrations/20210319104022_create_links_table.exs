defmodule GlobalApi.Repo.Migrations.CreateLinksTable do
  use Ecto.Migration

  def change do
    create table(:links, primary_key: false) do
      add :bedrock_id, :bigint, primary_key: true
      add :java_id, :string, size: 36
      add :java_name, :string, size: 16

      timestamps(type: :bigint)
    end

    alter table(:links) do
      # default value is the current unix time in ms
      modify(:inserted_at, :timestamp, default: fragment("FLOOR(UNIX_TIMESTAMP(NOW(3)) * 1000)"))
      modify(:updated_at, :timestamp, default: fragment("FLOOR(UNIX_TIMESTAMP(NOW(3)) * 1000)"))
    end

    create(index("links", [:java_id]))
    create(unique_index("links", [:bedrock_id, :java_id]))
  end
end
