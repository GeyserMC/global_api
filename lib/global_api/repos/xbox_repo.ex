defmodule GlobalApi.XboxRepo do
  alias GlobalApi.Repo
  alias GlobalApi.XboxIdentity
  import Ecto.Query

  def get_by_xuid(xuid) do
    Repo.one(from i in XboxIdentity, where: i.xuid == ^xuid)
  end

  def get_by_gamertag(gamertag) do
    Repo.one(
      from i in XboxIdentity,
      where: i.gamertag == ^gamertag,
      order_by: [
        desc: :inserted_at
      ],
      limit: 1
    )
  end

  def get_least_recent_updated(result_limit) do
    Repo.all(
      from i in XboxIdentity,
      order_by: [
        asc: :inserted_at
      ],
      limit: ^result_limit
    )
  end

  def insert_new(xuid, gamertag) do
    Repo.insert(create({xuid, gamertag, :os.system_time(:millisecond)}))
  end

  def insert_bulk(identities) do
    Repo.insert_all(XboxIdentity, identities, on_conflict: :nothing)
  end

  def remove_by_xuid(xuid) do
    Repo.delete_all(from i in XboxIdentity, where: i.xuid == ^xuid)
  end

  def handle_extra_data({xuid, gamertag, issued_at} = data) do
    #todo use the cache
    # we can't combine on_conflict with a where in mysql
    # it also doesn't support 'read after writes' for non-primary keys
    case Repo.insert(create(data)) do
      {:ok, _} -> :ok
      {:error, _} ->
        # we only expect a duplicate key error
        Repo.update_all(
          from(i in XboxIdentity, where: i.xuid == ^xuid and i.inserted_at < ^issued_at),
          set: [
            gamertag: gamertag,
            inserted_at: issued_at
          ]
        )
    end
  end

  defp create({xuid, gamertag, issued_at}) do
    %XboxIdentity{}
    |> XboxIdentity.changeset(%{xuid: xuid, gamertag: gamertag, inserted_at: issued_at})
  end
end
