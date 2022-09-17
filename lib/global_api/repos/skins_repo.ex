defmodule GlobalApi.SkinsRepo do
  import Ecto.Query

  alias GlobalApi.Repo
  alias GlobalApi.PlayerSkin
  alias GlobalApi.UniqueSkin

  def get_player_skin(xuid) do
    Repo.one(
      from s in PlayerSkin,
      join: u in assoc(s, :skin),
      where: s.bedrock_id == ^xuid,
      preload: [skin: u]
    )
  end

  def get_skin(skin_id) do
    Repo.one(
      from s in UniqueSkin,
      where: s.id == ^skin_id
    )
  end

  def get_skin_sample(skin_id, sample_size) when is_integer(sample_size) do
    Repo.all(
      from s in PlayerSkin,
      select: s.bedrock_id,
      where: s.skin_id == ^skin_id,
      limit: ^sample_size
    )
  end

  def get_skin_usage(skin_id) do
    Repo.one(
      from s in PlayerSkin,
      select: count(),
      where: s.skin_id == ^skin_id
    )
  end

  def get_player_skin_id(xuid) do
    Repo.one(
      from s in PlayerSkin,
      select: {s.skin_id, s.updated_at},
      where: s.bedrock_id == ^xuid
    )
  end

  def get_most_recent(limit) do
    Repo.all(
      from s in PlayerSkin,
      order_by: [desc: :inserted_at],
      limit: ^limit,
      join: u in assoc(s, :skin),
      preload: [skin: u],
      select: {u.id, s.bedrock_id, u.texture_id}
    )
  end

  def get_most_recent_unique(limit) do
    Repo.all(
      from u in UniqueSkin,
      select: map(u, [:id, :texture_id]),
      order_by: [desc: :inserted_at],
      limit: ^limit
    )
  end

  def most_popular(limit) do
    popular = from(
      s in PlayerSkin,
      select: %{skin_id: s.skin_id, count: count()},
      group_by: :skin_id,
      order_by: [desc: count()],
      limit: ^limit
    )

    Repo.all(
      from u in UniqueSkin,
      select: map(u, [:id, :texture_id]),
      right_join: s in subquery(popular),
      on: s.skin_id == u.id,
      limit: ^limit # just to be sure :sweat_smile:
    )
  end

  # max_age in seconds
  def get_recently_uploaded(max_age) do
    Repo.one(
      from s in UniqueSkin,
      select: count(),
      where: fragment("inserted_at > (UNIX_TIMESTAMP() - ?) * 1000", ^max_age)
    )
  end

  def create_skin(attrs \\ %{}) do
    %PlayerSkin{}
    |> PlayerSkin.changeset(attrs)
    |> Repo.insert(on_conflict: {:replace_all_except, [:inserted_at]}, source: :player_skins)
  end

  def get_unique_skin(hash, is_steve) when is_binary(hash) do
    Repo.one(from s in UniqueSkin, where: s.hash == ^hash and s.is_steve == ^is_steve, limit: 1)
  end

  def create_unique_skin(attrs) when is_map(attrs) do
    %UniqueSkin{}
    |> UniqueSkin.changeset(attrs)
    |> Repo.insert!(on_conflict: :nothing, source: :unique_skins)
    # on conflict id will be nil
  end

  def create_or_get_unique_skin(attrs) when is_map(attrs) do
    skin_id = create_unique_skin(attrs).id
    # I don't think that this will ever happen, but just in case
    if skin_id == nil do
      get_unique_skin(attrs.hash, attrs.is_steve).id
    else
      skin_id
    end
  end

  def set_skin(xuid, %UniqueSkin{} = unique_skin) do
    set_skin(xuid, unique_skin.id)
  end

  def set_skin(xuid, skin_id) when is_integer(skin_id) do
    # easiest place to place this
    :telemetry.execute([:global_api, :metrics, :skins, :player_updated], %{count: 1})

    %{
      bedrock_id: xuid,
      skin_id: skin_id
    }
    |> create_skin
  end
end
