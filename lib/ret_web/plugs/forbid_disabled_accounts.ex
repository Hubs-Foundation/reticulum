defmodule RetWeb.Plugs.ForbidDisabledAccounts do
  import Plug.Conn

  def init([]), do: []

  def call(conn, []) do
    account = Guardian.Plug.current_resource(conn)

    case account do
      %Ret.Account{state: :disabled} -> conn |> send_resp(401, "") |> halt()
      _ -> conn
    end
  end
end
