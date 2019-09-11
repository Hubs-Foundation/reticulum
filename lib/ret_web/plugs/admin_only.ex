defmodule RetWeb.Plugs.AdminOnly do
  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    # Put account in into assigns for Canary to consume.
    account = Guardian.Plug.current_resource(conn)

    if account.is_admin do
      conn
    else
      conn
      |> put_status(:unauthorized)
      |> halt()
    end
  end
end
