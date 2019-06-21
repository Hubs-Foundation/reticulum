defmodule Ret.TwitterClient do
  import Ret.HttpUtils

  @twitter_api_base "https://api.twitter.com"

  def get_oauth_url(hub_sid, account_id) do
    creds =
      OAuther.credentials(
        consumer_key: module_config(:consumer_key),
        consumer_secret: module_config(:consumer_secret),
        token: module_config(:access_token),
        token_secret: module_config(:access_token_secret)
      )

    token = Ret.OAuthToken.token_for_hub_and_account(hub_sid, account_id)
    callback_url = "#{get_redirect_uri()}?state=#{token}"
    res = post("/oauth/request_token", [{"oauth_callback", callback_url}], creds)
    "#{@twitter_api_base}/oauth/authorize?" <> URI.encode_query(%{oauth_token: res["oauth_token"]})
  end

  def get_access_token_and_user_info(oauth_verifier, request_token) do
    creds =
      OAuther.credentials(
        consumer_key: module_config(:consumer_key),
        consumer_secret: module_config(:consumer_secret),
        token: request_token
      )

    post("/oauth/access_token", [{"oauth_verifier", oauth_verifier}], creds)
  end

  defp get(path, params, creds) do
    url = "#{@twitter_api_base}#{path}"

    oauther_params = OAuther.sign("get", url, params, creds)
    encoded_params = URI.encode_query(oauther_params)
    request_url = "#{url}?#{encoded_params}"

    retry_get_until_success(request_url)
    |> Map.get(:body)
    |> Poison.decode!()
  end

  defp post(path, params, creds) do
    url = "#{@twitter_api_base}/#{path}"

    params = OAuther.sign("post", url, params, creds)
    encoded_params = URI.encode_query(params)

    retry_post_until_success(url, encoded_params, [{"content-type", "application/x-www-form-urlencoded"}])
    |> Map.get(:body)
    |> to_string
    |> URI.decode_query()
  end

  defp get_redirect_uri(), do: RetWeb.Endpoint.url() <> "/api/v1/oauth/twitter"

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
