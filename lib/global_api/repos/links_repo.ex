defmodule GlobalApi.LinksRepo do
  alias GlobalApi.Link
  alias GlobalApi.Repo
  alias GlobalApi.UUID
  import Ecto.Query

  def get_java_link(uuid) do
    Repo.all(from l in Link, where: l.java_id == ^uuid) || []
  end

  def get_bedrock_link(xuid) do
    Repo.one(from l in Link, where: l.bedrock_id == ^xuid) || %{}
  end

  def update_link(%Link{} = link, attrs \\ %{}) do
    # see the web_socket module
    link
    |> Link.changeset(attrs)
    |> Repo.update()
  end

  def create_link(xuid, uuid, username) do
    %Link{}
    |> Link.changeset(%{bedrock_id: xuid, java_id: UUID.cast!(uuid), java_name: username})
    |> Repo.insert(on_conflict: :replace_all) #lazy fix
  end
end
