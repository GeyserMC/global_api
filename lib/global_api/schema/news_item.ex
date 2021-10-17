defmodule GlobalApi.NewsItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, []}
  schema "news" do
    field :project, :string
    field :active, :boolean
    field :type, Ecto.Enum, values: [:build_specific, :check_after, :announcement, :config_specific]
    field :data, :map
    field :message, :map
    field :actions,
          {:array, Ecto.Enum},
          values: [
            :on_server_started,
            :on_operator_join,
            :broadcast_to_controle,
            :broadcast_to_operators
          ]
    field :url, :string
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:id, :project, :active, :type, :data, :priority, :message, :actions, :url])
    |> validate_required(
         [:id, :project, :active, :type, :data, :priorty, :message, :actions, :url],
         message: "news item is not complete"
       )
  end

  def to_public_v1(%__MODULE__{} = item) do
    %{
      id: item.id,
      project: item.project,
      active: item.active,
      type: item.type,
      data: item.data,
      priority: false,
      message: %{
        id: item.message.id,
        args: item.message.args
      },
      actions: item.actions,
      url: item.url
    }
  end

  def to_public_v2(%__MODULE__{} = item) do
    %{
      id: item.id,
      active: item.active,
      type: item.type,
      data: item.data,
      message: %{
        id: item.message.id,
        args: item.message.args
      },
      actions: item.actions,
      url: item.url
    }
  end
end
