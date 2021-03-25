defmodule GlobalApi.MetricsRepo do
  alias GlobalApi.Metric
  alias GlobalApi.Repo

  def set_metric(name, value) do
    %Metric{}
    |> Metric.changeset(%{name: name, value: value})
    |> Repo.insert(on_conflict: :replace_all)
  end
end
