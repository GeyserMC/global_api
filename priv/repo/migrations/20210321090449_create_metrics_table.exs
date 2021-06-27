defmodule GlobalApi.Repo.Migrations.CreateMetricsTable do
  use Ecto.Migration

  def change do
    create table(:metrics, primary_key: false) do
      add :name, :string, size: 32, primary_key: true
      add :value, :integer
    end
  end
end
