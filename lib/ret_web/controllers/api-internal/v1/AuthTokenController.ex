defmodule RetWeb.ApiInternal.V1.AuthTokenController do
  require Logger

  use RetWeb, :controller

  def post(conn, %{"email" => email}) when is_binary(email) do
    if System.get_env("TURKEY_MODE") do
      {:ok, token, _params} =
        email
        |> Ret.Account.account_for_email()
        |> Ret.Guardian.encode_and_sign()

      send_resp(conn, 200, token)
    else
      send_resp(conn, 404, "")
    end
  end
end
