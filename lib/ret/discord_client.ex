defmodule Ret.DiscordClient do
  @oauth_scope "identify email"
  @discord_api_base "https://discordapp.com/api/v6"
  def get_oauth_url(hub_sid) do
    authorize_params = %{
      response_type: "code",
      client_id: module_config(:client_id),
      scope: @oauth_scope,
      state: Ret.OAuthToken.token_for_hub(hub_sid),
      redirect_uri: get_redirect_uri
    }

    "#{@discord_api_base}/oauth2/authorize?" <> URI.encode_query(authorize_params)
  end

  def get_access_token(oauth_code) do
    body = {
      :form,
      [
        client_id: module_config(:client_id),
        client_secret: module_config(:client_secret),
        grant_type: "authorization_code",
        code: oauth_code,
        redirect_uri: get_redirect_uri,
        scope: @oauth_scope
      ]
    }

    HTTPoison.post!("#{@discord_api_base}/oauth2/token", body, %{
      "content-type" => "application/x-www-form-urlencoded"
    })
    |> Map.get(:body)
    |> Poison.decode!()
    |> Map.get("access_token")
  end

  def get_user_info(access_token) do
    HTTPoison.get!("#{@discord_api_base}/users/@me", %{"authorization" => "Bearer #{access_token}"})
    |> Map.get(:body)
    |> Poison.decode!()
  end

  defp get_redirect_uri(), do: RetWeb.Endpoint.url() <> "/api/v1/oauth/discord"

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
