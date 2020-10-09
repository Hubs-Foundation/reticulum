defmodule RetWeb.AddAbsintheContext do
  @moduledoc false
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _) do
    Absinthe.Plug.put_options(conn,
      context: %{
        auth_error: conn.assigns[:auth_error],
        claims: Guardian.Plug.current_claims(conn),
        account: Guardian.Plug.current_resource(conn),
        token: Guardian.Plug.current_token(conn)
      }
    )
  end
end
