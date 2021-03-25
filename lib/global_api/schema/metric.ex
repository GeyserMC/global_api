defmodule GlobalApi.Metric do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:name, :string, []}
  schema "metrics" do
    field :value, :integer
  end

  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [:name, :value])
    |> validate_required([:name, :value], message: "cannot add an incomplete metric")
  end
end
