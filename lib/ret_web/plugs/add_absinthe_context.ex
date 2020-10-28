defmodule RetWeb.AddAbsintheContext do
  @moduledoc false
  @behaviour Plug

  alias Ret.Api.Credentials

  def init(opts), do: opts

  def call(conn, _) do
    Absinthe.Plug.put_options(conn, context: build_context(conn))
  end

  defp build_context(conn) do
    auth_errors = conn.assigns[:api_token_auth_errors] || []
    credentials = Guardian.Plug.current_claims(conn)
    %{
      api_token_auth_errors: auth_errors,
      credentials: credentials
    }
  end
end
