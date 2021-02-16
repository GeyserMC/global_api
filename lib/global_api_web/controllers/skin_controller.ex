defmodule GlobalApiWeb.SkinController do
  use GlobalApiWeb, :controller
  alias GlobalApi.Repo
  alias GlobalApi.Utils

  def get_skin(conn, %{"xuid" => xuid}) do
    case Utils.is_int_and_rounded(xuid) do
      false ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, message: "xuid should be an int"})

      true ->
        {_, result} = Cachex.fetch(:texture_id_by_xuid, xuid, fn _ ->
          case Repo.get_texture_id_by_xuid(xuid) do
            :not_found ->
              {:ignore, :not_found}
            {texture_id, last_update} ->
              {:commit, {texture_id, last_update}}
          end
        end)

        if result === :not_found do
          json(conn, %{success: true, data: %{}})
        else
          {texture_id, last_update} = result
          json(conn, %{success: true, data: %{texture_id: texture_id, last_update: last_update}})
        end
    end
  end
end
