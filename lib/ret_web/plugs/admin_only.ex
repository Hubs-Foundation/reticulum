# Terminates the pipeline if the user is not currently logged in or if they are not an administrator.
defmodule RetWeb.Plugs.AdminOnly do
  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    # Put account in into assigns for Canary to consume.
    account = Guardian.Plug.current_resource(conn)

    if account && account.is_admin do
      conn
    else
      conn
      |> send_resp(401, "Not authorized")
      |> halt()
    end
  end
end
