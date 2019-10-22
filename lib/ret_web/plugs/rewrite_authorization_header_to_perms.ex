# Injects an Authorization header into the conn request headers that has the perms token of the 
# currently logged in user. This is used during PostgREST proxying.
defmodule RetWeb.Plugs.RewriteAuthorizationHeaderToPerms do
  import Plug.Conn

  def init([]), do: []

  def call(conn, []) do
    account = Guardian.Plug.current_resource(conn)

    token =
      %{}
      |> Ret.Account.add_global_perms_for_account(account)
      |> Map.put(:account_id, account.account_id)
      |> Ret.PermsToken.token_for_perms()

    conn
    |> delete_req_header("authorization")
    |> put_req_header("authorization", "Bearer #{token}")
  end
end
