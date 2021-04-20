defmodule RetWeb.Guardian.AuthErrorHandler do
  @moduledoc false
  import Plug.Conn

  def auth_error(conn, {type, _reason}, _opts) do
    body = Poison.encode!(%{error: to_string(type)})
    send_resp(conn, 401, body)
  end
end
