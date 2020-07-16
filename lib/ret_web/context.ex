defmodule RetWeb.Context do
  @behaviour Plug

  import Plug.Conn
  import Ecto.Query, only: [where: 2]

  alias RetWeb.{Repo, User}

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