defmodule GlobalApi.XboxUtils do
  @moduledoc false
  alias GlobalApi.Utils

  @token_url "https://login.live.com/oauth20_token.srf"
  @authenticate_url "https://user.auth.xboxlive.com/user/authenticate"
  @authorize_url "https://xsts.auth.xboxlive.com/xsts/authorize"

  def load_token_data() do
    case File.read("token_cache.json") do
      {:ok, body} ->
        result =
          Jason.decode!(body)
          |> keys_to_atoms
        %{
          result |
          data: Enum.map(result.data, fn data -> keys_to_atoms(data) end),
          updater: keys_to_atoms(result.updater)
        }
      {:error, _} -> nil
    end
  end

  def keys_to_atoms(data) do
    Map.new(data, fn {k, v} -> {String.to_atom(k), v} end)
  end

  def get_info() do
    {
      Utils.get_env(:app_info, :client_id),
      Utils.get_env(:app_info, :redirect_url),
      Utils.get_env(:app_info, :client_secret)
    }
  end

  def get_link_info(query_info) do
    query_info = if query_info != nil do query_info else "" end
    {
      Utils.get_env(:link_app_info, :client_id),
      Utils.get_env(:link_app_info, :redirect_url) <> "#{query_info}",
      Utils.get_env(:link_app_info, :client_secret)
    }
  end

  def not_setup_message() do
    %{
      success: false,
      message: "The Xbox Api isn't setup correctly. Please contact a GeyserMC developer"
    }
  end

  def save_token_data(token_data) do
    File.write("token_cache.json", Jason.encode!(%{updater: token_data.updater, data: token_data.data}))
  end

  def check_token_data(%{} = data) when map_size(data) == 0 do
    {:ok, data}
  end

  def check_token_data(
        %{
          refresh_token: refresh_token,
          auth_token: auth_token,
          auth_token_valid_until: auth_token_valid_until,
          xbox_token_valid_until: xbox_token_valid_until
        } = data
      ) do
    current_datetime = :os.system_time(:second)
    # the updater checks every hour. + 1 minute just to be sure
    min_remaining_time = 61 * 60

    # we're ok when the xbox token is valid
    case (xbox_token_valid_until - current_datetime) > min_remaining_time do
      true -> {:ok, data}
      _ ->
        # we can reuse the auth token as long as it's valid
        case (auth_token_valid_until - current_datetime) > min_remaining_time do
          true ->
            {xbox_token, xbox_token_valid_until} = start_xbox_setup(auth_token)
            {:update, %{data | xbox_token: xbox_token, xbox_token_valid_until: xbox_token_valid_until}}
          false ->
            # we have revive the session using the refresh token
            {state, data} = start_initial_xbox_setup(refresh_token, true)
            if state == :ok do
              {:update, data}
            else
              {:error, data}
            end
        end
    end
  end

  def check_and_save_token_data(token_data) do
    case check_token_data(token_data.updater) do
      {:error, reason} -> {:error, "#{reason} - updater"}
      {_, updater_data} ->
        data = check_token_data_array(token_data.data, [])
        result = %{updater: updater_data, data: data}
        case save_token_data(result) do
          :ok -> {:ok, result}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp check_token_data_array([], result), do: result

  defp check_token_data_array([entry | rest], result) do
    case check_token_data(entry) do
      {:ok, data} -> check_token_data_array(rest, [data | result])
      {:update, data} -> check_token_data_array(rest, [data | result])
      {:error, reason} -> {:error, "#{reason} - no #{length(result) + 1}"}
    end
  end

  def start_initial_xbox_setup(code, is_refresh \\ false, link \\ false, query_info \\ nil, is_java \\ false) do
    info = if link do get_link_info(query_info) else get_info() end
    json_response = request_token(info, code, is_refresh, link)

    if json_response["error"] != nil do
      if !link do
        IO.puts("Error while requesting token: " <> json_response["error"])
        IO.puts("Description: " <> json_response["error_description"])
      end
      {:error, json_response["error_description"]}
    else
      access_token = json_response["access_token"]
      refresh_token = json_response["refresh_token"]

      json_response = request_authentication(access_token)

      auth_token = json_response["Token"]
      {:ok, auth_token_valid_until, 0} = DateTime.from_iso8601(json_response["NotAfter"])
      auth_token_valid_until = DateTime.to_unix(auth_token_valid_until)
      uhs = Enum.at(json_response["DisplayClaims"]["xui"], 0)["uhs"]

      relying_party = if is_java do "rp://api.minecraftservices.com/" else "http://xboxlive.com" end
      json_response = request_authorization(auth_token, relying_party)

      if Map.has_key?(json_response, "XErr") do
        {:error, json_response["XErr"]}
      else
        xbox_token = json_response["Token"]

        {:ok, xbox_token_valid_until, 0} = DateTime.from_iso8601(json_response["NotAfter"])
        if !link do
          IO.puts("Successfully completed the initial xbox setup! We don't have to do anything until #{DateTime.to_string(xbox_token_valid_until)}")
          IO.puts("We have to restart this process around #{DateTime.to_string(DateTime.from_unix!(auth_token_valid_until))}")
        end
        xbox_token_valid_until = DateTime.to_unix(xbox_token_valid_until)

        {
          :ok,
          %{
            access_token: access_token,
            refresh_token: refresh_token,
            auth_token: auth_token,
            auth_token_valid_until: auth_token_valid_until,
            uhs: uhs,
            xbox_token: xbox_token,
            xbox_token_valid_until: xbox_token_valid_until
          }
        }
      end
    end
  end

  def start_xbox_setup(auth_token) do
    json_response = request_authorization(auth_token)

    xbox_token = Map.get(json_response, "Token")
    {:ok, xbox_token_valid_until, 0} = DateTime.from_iso8601(json_response["NotAfter"])
    IO.puts("Successfully completed the xbox setup! We don't have to do anything until #{DateTime.to_string(xbox_token_valid_until)}")
    xbox_token_valid_until = DateTime.to_unix(xbox_token_valid_until)
    {xbox_token, xbox_token_valid_until}
  end

  defp request_token({client_id, redirect_url, client_secret}, code, is_refresh, is_link) do
    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    scope = if is_link do "Xboxlive.signin" else "Xboxlive.offline_access" end

    body = "client_id=" <> client_id <> "&scope=" <> scope <> "&redirect_uri=" <> redirect_url <> "&client_secret=" <> client_secret
    body = body <>
           if is_refresh do
             "&grant_type=refresh_token&refresh_token="
           else
             "&grant_type=authorization_code&code="
           end

    {:ok, response} = HTTPoison.post(@token_url, body <> code, headers)
    Jason.decode!(response.body)
  end

  defp request_authentication(access_token) do
    headers = [
      {"Content-Type", "application/json"},
      {"x-xbl-contract-version", 1}
    ]

    body = Jason.encode!(
      %{
        RelyingParty: "http://auth.xboxlive.com",
        TokenType: "JWT",
        Properties: %{
          AuthMethod: "RPS",
          SiteName: "user.auth.xboxlive.com",
          RpsTicket: "d=" <> access_token
        }
      }
    )

    {:ok, response} = HTTPoison.post(@authenticate_url, body, headers)
    Jason.decode!(response.body)
  end

  defp request_authorization(auth_token, relying_party \\ "http://xboxlive.com") do
    headers = [
      {"Content-Type", "application/json"},
      {"x-xbl-contract-version", 1}
    ]

    body = Jason.encode!(
      %{
        RelyingParty: relying_party,
        TokenType: "JWT",
        Properties: %{
          UserTokens: [auth_token],
          SandboxId: "RETAIL"
        }
      }
    )

    {:ok, response} = HTTPoison.post(@authorize_url, body, headers)
    Jason.decode!(response.body)
  end

end
