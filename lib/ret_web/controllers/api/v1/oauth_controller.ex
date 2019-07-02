defmodule RetWeb.Api.V1.OAuthController do
  use RetWeb, :controller

  alias Ret.{Repo, OAuthToken, OAuthProvider, DiscordClient, TwitterClient, Hub, Account, PermsToken}

  plug(RetWeb.Plugs.RateLimit when action in [:show])

  def show(conn, %{"type" => "discord", "state" => state, "code" => code}) do
    %{claims: %{"hub_sid" => hub_sid}} = OAuthToken.peek(state)
    hub = Hub |> Repo.get_by(hub_sid: hub_sid)

    case OAuthToken.decode_and_verify(state) do
      {:ok, _} ->
        %{"id" => discord_user_id, "email" => email, "verified" => verified} =
          code |> DiscordClient.fetch_access_token() |> DiscordClient.fetch_user_info()

        hub = hub |> Repo.preload(:hub_bindings)

        conn
        |> process_discord_oauth(discord_user_id, verified, email, hub)
        |> put_resp_header("location", hub |> Hub.url_for())
        |> send_resp(307, "")

      {:error, :token_expired} ->
        conn
        |> put_resp_header("location", hub |> Hub.url_for())
        |> send_resp(307, "")
    end
  end

  def show(conn, %{"type" => "discord", "error" => "access_denied", "state" => state}) do
    %{claims: %{"hub_sid" => hub_sid}} = OAuthToken.peek(state)
    hub = Hub |> Repo.get_by(hub_sid: hub_sid)

    conn
    |> put_resp_header("location", hub |> Hub.url_for())
    |> send_resp(307, "")
  end

  def show(conn, %{
        "type" => "twitter",
        "state" => state,
        "oauth_token" => oauth_token,
        "oauth_verifier" => oauth_verifier
      }) do
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

  # Discord user has a verified email, so we create a Hubs account for them associate it with their discord user id.
  defp process_discord_oauth(conn, discord_user_id, true = _verified, email, _hub) do
    oauth_provider =
      OAuthProvider
      |> Repo.get_by(source: :discord, provider_account_id: discord_user_id)
      |> Repo.preload(:account)

    account = oauth_provider |> account_for_oauth_provider(email, discord_user_id)

    credentials = %{
      email: email,
      token: account |> Account.credentials_for_account()
    }

    conn |> put_short_lived_cookie("ret-oauth-flow-account-credentials", credentials |> Poison.encode!())
  end

  # Discord user does not have a verified email, so we can't create an account for them. Instead, we generate a perms
  # token to let them join the hub if permitted.
  defp process_discord_oauth(conn, discord_user_id, false = _verified, _email, hub) do
    oauth_provider = %Ret.OAuthProvider{provider_account_id: discord_user_id, source: :discord}

    perms_token =
      hub
      |> Hub.perms_for_account(oauth_provider)
      |> Map.put(:oauth_account_id, discord_user_id)
      |> Map.put(:oauth_source, :discord)
      |> PermsToken.token_for_perms()

    conn |> put_short_lived_cookie("ret-oauth-flow-perms-token", perms_token)
  end

  defp process_twitter_oauth(conn, account, access_token, access_token_secret, twitter_user_id) do
    # TODO deal with case where we get a user's email and may create an account

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

  # If an oauthprovider exists for the given discord_user_id, return the associated account, updating the email
  # if necessary.
  defp account_for_oauth_provider(%OAuthProvider{} = oauth_provider, email, _discord_user_id) do
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
  defp account_for_oauth_provider(nil = _oauth_provider, email, discord_user_id) do
    account = email |> Account.account_for_email()

    (OAuthProvider |> Repo.get_by(source: :discord, account_id: account.account_id) ||
       %OAuthProvider{source: :discord, account: account})
    |> Ecto.Changeset.change(provider_account_id: discord_user_id)
    |> Repo.insert_or_update()

    account
  end

  defp put_short_lived_cookie(conn, key, value) do
    conn |> put_resp_cookie(key, value, http_only: false, max_age: 5 * 60)
  end
end
