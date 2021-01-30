defmodule GlobalLinking.SkinUtils do
  @moduledoc false

  @mojang_public_key :jose_jwk.from_pem_file("mojang_public_key.pem")

  @steve_geometry_data "ewogICAiZ2VvbWV0cnkiIDogewogICAgICAiZGVmYXVsdCIgOiAiZ2VvbWV0cnkuaHVtYW5vaWQuY3VzdG9tIgogICB9Cn0K"
  @alex_geometry_data "ewogICAiZ2VvbWV0cnkiIDogewogICAgICAiZGVmYXVsdCIgOiAiZ2VvbWV0cnkuaHVtYW5vaWQuY3VzdG9tQWxleCIKICAgfQp9Cg=="

  def get_skin_modal(geometry_data) do
    case geometry_data do
      @steve_geometry_data -> :steve
      @alex_geometry_data -> :alex
      _ -> :unknown
    end
  end

  def verify_client_data(client_data, last_key) do
    case JOSE.JWT.verify_strict(last_key, ["ES384"], client_data) do
      {true, jwt, jws} ->
        {:ok, jwt}
      _ -> :error
    end
  end

  @spec verify_chain_data(Array.t()) :: {:ok, Map.t(), String.t()} | :invalid | :error
  def verify_chain_data(chain_data) do
    verify_chain_data(chain_data, nil, nil)
  end

  defp verify_chain_data([], last_key, nil), do: :invalid
  defp verify_chain_data([], last_key, last_data), do: {:ok, last_key, last_data}

  defp verify_chain_data([head | tail], last_data, last_key) do
    correct_key = if last_key == nil, do: @mojang_public_key, else: last_key
    case JOSE.JWT.verify_strict(correct_key, ["ES384"], head) do
      {true, jwt, _} ->
        verify_chain_data(tail, jwt.fields, create_key(jwt.fields["identityPublicKey"]))
      {false, _, _} ->
        if last_key == nil do
          # while we can seek the body, we don't have to
          verify_chain_data(tail, nil, nil)
        else
          :invalid
        end
      _ -> :error
    end
  end

  defp create_key(public_key) do
    :jose_jwk.from_pem("-----BEGIN PUBLIC KEY-----\n#{public_key}\n-----END PUBLIC KEY-----\n")
  end
end
