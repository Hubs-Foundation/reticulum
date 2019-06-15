defmodule Ret.TwitterClient do
  import Ret.HttpUtils

  @twitter_api_base "https://api.twitter.com"

  def get_oauth_url(hub_sid) do
    creds =
      OAuther.credentials(
        consumer_key: module_config(:consumer_key),
        consumer_secret: module_config(:consumer_secret),
        token: module_config(:access_token),
        token_secret: module_config(:access_token_secret)
      )

    url = "#{@twitter_api_base}/oauth/request_token"
    token = Ret.OAuthToken.token_for_hub(hub_sid)
    callback_url = "#{get_redirect_uri()}?state=#{token}"

    params = OAuther.sign("post", url, [{"oauth_callback", callback_url}], creds)
    encoded_params = URI.encode_query(params)

    res =
      retry_post_until_success(url, encoded_params, [{"content-type", "application/x-www-form-urlencoded"}])
      |> Map.get(:body)
      |> to_string
      |> URI.decode_query()

    "#{@twitter_api_base}/oauth/authorize?" <> URI.encode_query(%{oauth_token: res["oauth_token"]})
  end

  defp get_redirect_uri(), do: RetWeb.Endpoint.url() <> "/api/v1/oauth/twitter"

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
