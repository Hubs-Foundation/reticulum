# Controller for interacting with the Twitter API for accounts connected to Twitter.
# This API probably can/will be revisited if we have multiple providers that need this kind
# of interface
defmodule RetWeb.Api.V1.TwitterController do
  use RetWeb, :controller
  alias Ret.{TwitterClient, Account}

  def tweets(conn, params) do
    account = Guardian.Plug.current_resource(conn)
    oauth_provider = Account.oauth_provider_for_source(account, :twitter)
    token = oauth_provider.provider_access_token
    token_secret = oauth_provider.provider_access_token_secret
    # result = TwitterClient.tweet(params["tweet"], token, token_secret)
    # IO.inspect(result)

    # conn |> send_resp(200, result |> Poison.encode!())
    conn
  end
end
