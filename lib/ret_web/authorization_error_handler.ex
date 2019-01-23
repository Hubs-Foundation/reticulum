defmodule RetWeb.Canary.AuthorizationErrorHandler do
  import Plug.Conn

  def authorization_error(conn) do
    body = Poison.encode!(%{error: "Forbidden"})

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(403, body)
    |> halt
  end
end
