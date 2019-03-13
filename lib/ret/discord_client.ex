defmodule Ret.DiscordClient do
  def get_oauth_url(hub_sid) do
    authorize_params = %{
      response_type: "code",
      client_id: module_config(:client_id),
      scope: "identify email",
      state: Ret.OAuthToken.token_for_hub(hub_sid),
      redirect_uri: RetWeb.Endpoint.url() <> "/api/v1/oauth/discord"
    }

    "https://discordapp.com/api/oauth2/authorize?" <> URI.encode_query(authorize_params)
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
