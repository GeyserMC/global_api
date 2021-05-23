defmodule GlobalApi.Repo.Migrations.CreateXboxIdentityTable do
  use Ecto.Migration

  def change do
    create table(:xbox_identity, primary_key: false) do
      add :xuid, :bigint, primary_key: true
      add :gamertag, :string, size: 64
      add :inserted_at, :bigint
    end

    # you'd expect that we make it unique,
    # but it makes updating without losing records much easier if it isn't unique
    create(index("xbox_identity", [:gamertag]))

    # used for updating an identity only when the row older than the given timestamp
    create(index("xbox_identity", [:xuid, :inserted_at]))
  end
end
