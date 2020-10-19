defmodule RetWeb.AddAbsintheContext do
  @moduledoc false
  @behaviour Plug

  alias Ret.Api.Credentials

  def init(opts), do: opts

  def call(conn, _) do
    auth_errors = conn.assigns[:api_token_auth_errors] || []

    context =
      case Credentials.from_resource_and_claims(
             Guardian.Plug.current_resource(conn),
             Guardian.Plug.current_claims(conn)
           ) do
        {:ok, credentials} ->
          %{
            api_token_auth_errors: auth_errors,
            credentials: credentials
          }

        {:error, reason} ->
          %{
            api_token_auth_errors: auth_errors ++ [{:invalid_credentials, reason}]
          }
      end

    Absinthe.Plug.put_options(conn, context: context)
  end
end
