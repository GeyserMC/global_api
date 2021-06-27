defmodule GlobalApi.Repo.Migrations.CreateJavaSkinsTables do
  use Ecto.Migration

  def change do
    create table(:java_skins, primary_key: false) do
      add :id, :string, size: 64, primary_key: true
      add :is_steve, :bool, primary_key: true
      add :value, :string, size: 1000
      add :signature, :string, size: 1000
    end
  end
end
