defmodule RetWeb.Context do
  @moduledoc false
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  def build_context(conn) do
    claims = Guardian.Plug.current_claims(conn)
    account = Guardian.Plug.current_resource(conn)

    %{claims: claims, account: account}
  end
end
