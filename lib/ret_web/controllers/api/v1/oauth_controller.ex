defmodule RetWeb.Api.V1.OAuthController do
  use RetWeb, :controller

  alias Ret.{Repo, OAuthToken, OAuthProvider, DiscordClient, SlackClient, TwitterClient, Hub, Account, PermsToken}
  import Canada, only: [can?: 2]

  plug(RetWeb.Plugs.RateLimit when action in [:show])

  # handle twitter oauth to allow users hubs to tweet
  def show(conn, %{
        "type" => "twitter",
        "state" => state,
        "oauth_token" => oauth_token,
        "oauth_verifier" => oauth_verifier
      }) do
    IO.puts("OAUTH CONTROLLER: inside show twitter type")
    %{claims: %{"hub_sid" => hub_sid, "account_id" => account_id}} = OAuthToken.peek(state)

    hub = Hub |> Repo.get_by(hub_sid: hub_sid)
    account = Account |> Repo.get_by(account_id: account_id |> Integer.parse() |> elem(0))

    case OAuthToken.decode_and_verify(state) do
      {:ok, _} ->
        %{"user_id" => twitter_user_id, "oauth_token" => access_token, "oauth_token_secret" => access_token_secret} =
          TwitterClient.get_access_token_and_user_info(oauth_verifier, oauth_token)

        conn
        |> process_twitter_oauth(account, access_token, access_token_secret, twitter_user_id)
        |> put_resp_header("location", hub |> Hub.url_for())
        |> send_resp(307, "")

      {:error, :token_expired} ->
        conn
        |> put_resp_header("location", hub |> Hub.url_for())
        |> send_resp(307, "")
    end
  end

  # handle the chat app oauth information: discord, slack etc.
  def show(conn, %{"type" => _type} = params) do
    IO.puts("1 OAUTH CONTROLLER: inside show chat app oauth")
    handle_chat_oauth(params, conn)
    # handle_oauth(type, params, conn)
  end

  # def handle_oauth(type, params, conn) do
  #   case params do
  #     %{"error" => _} -> handle_chat_error(params, conn)
  #     _ -> handle_chat_oauth(params, conn)
  #   end
  # end

  # def handle_chat_error(params, conn) do
  #   case


  # def handle_oauth("slack", params, conn) do
  #   case params do
  #     %{"error" => _} -> handle_chat_error(params)
  #     _ -> handle_chat_oauth(params)
  #   end
  # end

  def handle_chat_oauth(params, conn) do
    IO.puts("2 OAUTH CONTROLLER: inside handle chat app oauth")
    %{"type" => type, "code" => code, "state" => state} = params

    %{claims: %{"hub_sid" => hub_sid}} = OAuthToken.peek(state)
    hub = Hub |> Repo.get_by(hub_sid: hub_sid)

    source = String.to_atom(type)
    module = case source do
      :discord -> DiscordClient
      :slack -> SlackClient
    end

    IO.puts("atom source printed")
    IO.puts(source)

    case OAuthToken.decode_and_verify(state) do
      {:ok, _} ->
        %{"id" => chat_user_id, "email" => email, "verified" => verified} =
          code |> module.fetch_access_token() |> module.fetch_user_info()

        hub = hub |> Repo.preload(:hub_bindings)

        conn
        |> process_chat_oauth(source, chat_user_id, verified, email, hub)
        |> put_resp_header("location", hub |> Hub.url_for())
        |> send_resp(307, "")

      {:error, :token_expired} ->
        conn
        |> put_resp_header("location", hub |> Hub.url_for())
        |> send_resp(307, "")
    end
  end



  # Discord user has a verified email, so we create a Hubs account for them associate it with their discord user id.
  defp process_chat_oauth(conn, source, chat_user_id, true = _verified, email, _hub) do
    IO.puts("3_1 OAUTH CONTROLLER: inside process_chat_oauth")

    oauth_provider =
      OAuthProvider
      |> Repo.get_by(source: source, provider_account_id: chat_user_id)
      |> Repo.preload(:account)

    account = oauth_provider |> account_for_oauth_provider(email, chat_user_id, source)

    credentials = %{
      email: email,
      token: account |> Account.credentials_for_account()
    }

    conn |> put_short_lived_cookie("ret-oauth-flow-account-credentials", credentials |> Poison.encode!())
  end

  # Discord user does not have a verified email, so we can't create an account for them. Instead, we generate a perms
  # token to let them join the hub if permitted.
  defp process_chat_oauth(conn, source, chat_user_id, false = _verified, _email, hub) do
    oauth_provider = %Ret.OAuthProvider{provider_account_id: chat_user_id, source: source}
    IO.puts("3_2 OAUTH CONTROLLER: inside process_chat_oauth")

    perms_token =
      hub
      |> Hub.perms_for_account(oauth_provider)
      |> Map.put(:oauth_account_id, chat_user_id)
      |> Map.put(:oauth_source, source)
      |> PermsToken.token_for_perms()

    conn |> put_short_lived_cookie("ret-oauth-flow-perms-token", perms_token) # Todo should this cookie support both discord and slack?
  end

  defp process_twitter_oauth(conn, account, access_token, access_token_secret, twitter_user_id) do
    # TODO deal with case where we get a user's email and may create an account
    IO.puts("OAUTH CONTROLLER: inside process_twitter_oauth")

    oauth_provider =
      OAuthProvider
      |> Repo.get_by(source: :twitter, provider_account_id: twitter_user_id)
      |> Repo.preload(:account)

    if !oauth_provider || oauth_provider.account.account_id == account.account_id do
      (oauth_provider || %OAuthProvider{source: :twitter, account: account})
      |> Ecto.Changeset.change(
        provider_access_token: access_token,
        provider_access_token_secret: access_token_secret,
        provider_account_id: twitter_user_id
      )
      |> Repo.insert_or_update!()

      conn
    else
      conn |> send_resp(401, "Another account is already connected to this twitter account.")
    end
  end

  # If an oauthprovider exists for the given discord_user_id (chat_user_id), return the associated account, updating the email
  # if necessary.
  defp account_for_oauth_provider(%OAuthProvider{} = oauth_provider, email, _chat_user_id, _source) do
    # ****
    IO.puts("4_1 OAUTH CONTROLLER: inside account_for_oauth_provider")
    account = oauth_provider.account |> Repo.preload(:login)
    login = account.login
    current_identifier_hash = login.identifier_hash
    identifier_hash = email |> Account.identifier_hash_for_email()

    if current_identifier_hash != identifier_hash do
      login |> Ecto.Changeset.change(identifier_hash: identifier_hash) |> Repo.update!()
    end

    account
  end

  # Create or get the account associated with the email and create or get an oauthprovider for that account.
  defp account_for_oauth_provider(nil = _oauth_provider, email, chat_user_id, source) do
    account = email |> Account.account_for_email(can?(nil, create_account(nil)))
    IO.puts("4_2 OAUTH CONTROLLER: inside account_for_oauth_provider")
    (OAuthProvider |> Repo.get_by(source: source, account_id: account.account_id) ||
       %OAuthProvider{source: source, account: account})
    |> Ecto.Changeset.change(provider_account_id: chat_user_id)
    |> Repo.insert_or_update()

    account
  end

  defp put_short_lived_cookie(conn, key, value) do
    conn |> put_resp_cookie(key, value, http_only: false, max_age: 5 * 60)
  end
end
