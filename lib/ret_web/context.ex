  # TODO: Naming: Absinthe Context?
defmodule RetWeb.Context do
  @moduledoc false
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  def build_context(conn) do
    # TODO: Should we be adding to context instead of overwriting?
    %{
      auth_error: conn.assigns[:auth_error],
      claims: Guardian.Plug.current_claims(conn),
      account: Guardian.Plug.current_resource(conn),
      token: Guardian.Plug.current_token(conn)
    }
  end
end
