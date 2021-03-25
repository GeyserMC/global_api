defmodule GlobalApi.SkinsRepo do
  alias GlobalApi.Repo
  alias GlobalApi.Skin
  import Ecto.Query

  def get_skin_by_id(id) do
    Skin
    |> Repo.get(id)
  end

  def create_skin(attrs \\ %{}) do
    %Skin{}
    |> Skin.changeset(attrs)
    |> Repo.insert(on_conflict: :replace_all)
  end

  def get_player_or_skin(xuid, hash, is_steve) when is_binary(hash) do
    Repo.one(
      from s in Skin, where: s.hash == ^hash and s.is_steve == ^is_steve,
                      order_by: [
                        desc: s.bedrock_id == ^xuid
                      ],
                      limit: 1
    )
  end

  def is_player_using_this(xuid, hash, is_steve) when is_binary(hash) do
    result = Repo.one(
      from s in "skins", select: count(s.bedrock_id),
                         where: s.bedrock_id == ^xuid and s.hash == ^hash and s.is_steve == ^is_steve
    )
    if result != nil do
      result > 0
    end
  end

  def get_skin_by_hash(hash, is_steve) when is_binary(hash) and is_boolean(is_steve) do
    Skin
    |> Repo.get_by([hash: hash, is_steve: is_steve])
  end

  def get_players_with_skin(hash, is_steve) when is_binary(hash) and is_boolean(is_steve) do
    Repo.all(from s in "skins", select: [:bedrock_id, :last_update], where: s.hash == ^hash and s.is_steve == ^is_steve)
  end

  def set_skin(xuid, hash, texture_id, value, signature, is_steve) do
    #todo none of the called methods do something with returned data
    %{
      bedrock_id: xuid,
      hash: hash,
      texture_id: texture_id,
      value: value,
      signature: signature,
      is_steve: is_steve
    }
    |> create_skin
  end
end
