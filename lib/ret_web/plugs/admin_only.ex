# Terminates the pipeline if the user is not currently logged in or if they are not an administrator.
defmodule RetWeb.Plugs.AdminOnly do
  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    # Put account in into assigns for Canary to consume.
    account = Guardian.Plug.current_resource(conn)
    main_host = RetWeb.Endpoint.config(:url)[:host]

    if account && account.is_admin do
      conn
    else
      conn
      |> resp(401, "Not authorized")
      |> send_resp()
      |> halt()
    end
  end
end
