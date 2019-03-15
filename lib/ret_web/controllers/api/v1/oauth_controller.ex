defmodule RetWeb.Api.V1.OAuthController do
  use RetWeb, :controller

  plug(RetWeb.Plugs.RateLimit when action in [:show])

  def show(conn, %{"type" => "discord", "state" => state, "code" => code}) do
    {:ok, claims} = Ret.OAuthToken.decode_and_verify(state)
    %{"hub_sid" => hub_sid} = claims

    %{"email" => email, "verified" => verified} =
      code |> Ret.DiscordClient.get_access_token() |> Ret.DiscordClient.get_user_info()

    url = Ret.Hub |> Ret.Repo.get_by(hub_sid: hub_sid) |> Ret.Hub.url_for()

    if verified do
      credentials = %{
        email: email,
        token: email |> Ret.Account.account_for_email() |> Ret.Account.credentials_for_account()
      }

      conn
      |> put_short_lived_cookie("ret-oauth-flow-account-credentials", credentials |> Poison.encode!())
      |> put_resp_header("location", url)
      |> send_resp(307, "")
    else
      perms_token = %{join_hub: true, kick_users: false} |> Ret.PermsToken.token_for_perms()

      conn
      |> put_short_lived_cookie("ret-oauth-flow-perms-token", perms_token)
      |> put_resp_header("location", url)
      |> send_resp(307, "")
    end

    conn |> send_resp(307, "")
  end

  defp put_short_lived_cookie(conn, key, value) do
    conn |> put_resp_cookie(key, value, http_only: false, max_age: 5 * 60)
  end
end
