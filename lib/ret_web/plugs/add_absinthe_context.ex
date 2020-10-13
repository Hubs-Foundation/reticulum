defmodule RetWeb.AddAbsintheContext do
  @moduledoc false
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _) do
    claims = Guardian.Plug.current_claims(conn)

    Absinthe.Plug.put_options(conn,
      context: %{
        api_token_auth_errors: conn.assigns[:api_token_auth_errors] || [],
        resource: Guardian.Plug.current_resource(conn),
        scopes: claims && claims["scopes"],
        token: Guardian.Plug.current_token(conn),
        claims: claims
      }
    )
  end
end
