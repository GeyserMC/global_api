defmodule GlobalLinking.XboxUtils do
  @moduledoc false
  alias GlobalLinking.Utils

  @token_url "https://login.live.com/oauth20_token.srf"
  @authenticate_url "https://user.auth.xboxlive.com/user/authenticate"
  @authorize_url "https://xsts.auth.xboxlive.com/xsts/authorize"

  def load_token_data() do
    case File.read("token_cache.json") do
      {:ok, body} ->
        Jason.decode!(body)
        |> keys_to_atoms
      {:error, _} -> nil
    end
  end

  def keys_to_atoms(data) do
    data
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
  end

  def get_info() do
    {
      Utils.get_env(:app, :client_id),
      Utils.get_env(:app, :redirect_url),
      Utils.get_env(:app, :client_secret)
    }
  end

  def not_setup_message() do
    %{
      success: false,
      message: "The Xbox Api isn't setup correctly. Please contact a GeyserMC developer"
    }
  end

  def save_token_data(data) do
    File.write("token_cache.json", Jason.encode!(Map.delete(data, :info)))
  end

  def check_token_data(
        %{
          refresh_token: refresh_token,
          auth_token: auth_token,
          auth_token_valid_until: auth_token_valid_until,
          xbox_token_valid_until: xbox_token_valid_until
        } = data,
        is_loading \\ false
      ) do
    current_datetime = :os.system_time(:second)
    # 10 minutes for stored data and 20 seconds for
    min_remaining_time = if is_loading, do: 600, else: 20

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

  def check_and_save_token_data(data) do
    case check_token_data(data) do
      {:ok, data} -> {:ok, data}
      {:update, data} ->
        case save_token_data(data) do
          :ok -> {:ok, data}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  def start_initial_xbox_setup(code, is_refresh \\ false) do
    json_response = request_token(get_info(), code, is_refresh)

    access_token = json_response["access_token"]
    refresh_token = json_response["refresh_token"]

    json_response = request_authentication(access_token)

    auth_token = json_response["Token"]
    {:ok, auth_token_valid_until, 0} = DateTime.from_iso8601(json_response["NotAfter"])
    auth_token_valid_until = DateTime.to_unix(auth_token_valid_until)
    uhs = Enum.at(json_response["DisplayClaims"]["xui"], 0)["uhs"]

    json_response = request_authorization(auth_token)

    if Map.has_key?(json_response, "XErr") do
      {:error, json_response["XErr"]}
    else
      xbox_token = json_response["Token"]

      {:ok, xbox_token_valid_until, 0} = DateTime.from_iso8601(json_response["NotAfter"])
      IO.puts("Successfully completed the initial xbox setup! We don't have to do anything until " <> DateTime.to_string(xbox_token_valid_until))
      IO.puts("We have to restart this process around " <> DateTime.to_string(DateTime.from_unix!(auth_token_valid_until)))
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

  def start_xbox_setup(auth_token) do
    json_response = request_authorization(auth_token)

    xbox_token = Map.get(json_response, "Token")
    {:ok, xbox_token_valid_until, 0} = DateTime.from_iso8601(json_response["NotAfter"])
    IO.puts("Successfully completed the xbox setup! We don't have to do anything until " <> DateTime.to_string(xbox_token_valid_until))
    xbox_token_valid_until = DateTime.to_unix(xbox_token_valid_until)
    {xbox_token, xbox_token_valid_until}
  end

  defp request_token({client_id, redirect_url, client_secret}, code, is_refresh) do
    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    body = "client_id=" <> client_id <> "&scope=Xboxlive.offline_access&code=" <> code <> "&redirect_uri=" <> redirect_url <> "&client_secret=" <> client_secret
    body = body <>
           if is_refresh do
             "&grant_type=refresh_token"
           else
             "&grant_type=authorization_code"
           end

    {:ok, response} = HTTPoison.post(@token_url, body, headers)
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

  defp request_authorization(auth_token) do
    headers = [
      {"Content-Type", "application/json"},
      {"x-xbl-contract-version", 1}
    ]

    body = Jason.encode!(
      %{
        RelyingParty: "http://xboxlive.com",
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
