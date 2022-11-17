defmodule RetWeb.ApiInternal.V1.AuthTokenController do
  require Logger

  use RetWeb, :controller

  def post(conn, %{"email" => email}) when is_binary(email) do
    {:ok, token, _params} =
      email
      |> Ret.Account.account_for_email()
      |> Ret.Guardian.encode_and_sign()

    send_resp(conn, 200, token)
  end
end
