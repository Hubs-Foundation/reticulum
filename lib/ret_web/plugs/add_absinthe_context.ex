defmodule RetWeb.AddAbsintheContext do
  @moduledoc false
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _) do
    Absinthe.Plug.put_options(conn, context: build_context(conn))
  end

  defp build_context(conn) do
    auth_errors = conn.assigns[:api_token_auth_errors] || []

    case Guardian.Plug.current_claims(conn) do
      {:error, :invalid_token} ->
        %{
          api_token_auth_errors:
            [{:invalid_token, "Invalid token error. Could not find credentials."}] ++ auth_errors
        }

      credentials ->
        %{
          api_token_auth_errors: auth_errors,
          credentials: credentials
        }
    end
  end
end
