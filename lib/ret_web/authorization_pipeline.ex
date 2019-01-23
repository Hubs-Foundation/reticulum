defmodule RetWeb.Canary.AuthorizationPipeline do
  def init(options), do: options

  def call(conn, _opts) do
    # Put account in into assigns for Canary to consume.
    account = Guardian.Plug.current_resource(conn)
    Plug.Conn.assign(conn, :current_user, account)
  end
end
