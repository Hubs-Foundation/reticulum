defmodule RetWeb.Context do
  @moduledoc false
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  def build_context(conn) do
    account = Guardian.Plug.current_resource(conn)

    if account do
      %{account: account}
    else
      %{}
    end
  end
end
