# Controller for interacting with the Twitter API for accounts connected to Twitter.
# This API probably can/will be revisited if we have multiple providers that need this kind
# of interface
defmodule RetWeb.Api.V1.TwitterController do
  use RetWeb, :controller
  alias Ret.{TwitterClient, Account}

  def tweets(conn, %{"media_stored_file_url" => media_stored_file_url, "body" => body}) do
    account = Guardian.Plug.current_resource(conn)
    oauth_provider = Account.oauth_provider_for_source(account, :twitter)
    token = oauth_provider.provider_access_token
    token_secret = oauth_provider.provider_access_token_secret

    case media_stored_file_url |> URI.parse() do
      %URI{path: "/files/" <> filename, query: query} ->
        [stored_file_uuid, _ext] = filename |> String.split(".")
        parsed_query = query |> URI.decode_query()
        stored_file_access_token = parsed_query["token"]

        case TwitterClient.upload_stored_file_as_media(
               stored_file_uuid,
               stored_file_access_token,
               account,
               token,
               token_secret
             ) do
          media_id when is_binary(media_id) ->
            res = TwitterClient.tweet(body, token, token_secret, media_id)
            conn |> send_resp(200, res)

          _ ->
            conn |> send_resp(400, "Failed uploading")
        end

      _ ->
        conn |> send_resp(400, "Invalid media stored file url")
    end
  end
end
