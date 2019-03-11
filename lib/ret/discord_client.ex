defmodule Ret.DiscordClient do
  def get_oauth_info() do
    nonce = :crypto.strong_rand_bytes(16) |> Base.encode16()

    authorize_params = %{
      response_type: "code",
      client_id: module_config(:client_id),
      scope: "identify email",
      state: nonce,
      redirect_uri: RetWeb.Endpoint.url() <> "/api/v1/oauth/discord"
    }

    %{
      type: :discord,
      nonce: nonce,
      url: "https://discordapp.com/api/oauth2/authorize?" <> URI.encode_query(authorize_params)
    }
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
