defmodule GlobalApi.LinksRepo do
  alias GlobalApi.Link
  alias GlobalApi.Repo
  import Ecto.Query

  def get_java_link(uuid) do
    Repo.all(from l in Link, where: l.java_id == ^uuid) || []
  end

  def get_bedrock_link(xuid) do
    Repo.one(from l in Link, where: l.bedrock_id == ^xuid) || %{}
  end

  def update_link(%Link{} = link, attrs \\ %{}) do
    #todo add force option, because when there are no changes, the function update is a no-op
    # see the web_socket module
    link
    |> Link.changeset(attrs)
    |> Repo.update()
  end
end
