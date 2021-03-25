defmodule GlobalApi.Repo.Migrations.CreateLinksTable do
  use Ecto.Migration

  def change do
    create table(:links, primary_key: false) do
      add :bedrock_id, :bigint, primary_key: true
      add :java_id, :string, size: 36
      add :java_name, :string, size: 16

      timestamps(type: :utc_datetime)
    end

    alter table(:links) do
      modify(:inserted_at, :timestamp, default: fragment("NOW()"))
      modify(:updated_at, :timestamp, default: fragment("NOW()"))
    end

    create(index("links", [:java_id]))
  end
end
