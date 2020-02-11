defmodule RetWeb.AccountControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Repo, Account}

  setup %{conn: conn} do
    {:ok, admin_account: admin_account} = create_admin_account("test")
    {:ok, token, _params} = admin_account |> Ret.Guardian.encode_and_sign()
    {:ok, account: admin_account, conn: conn |> Plug.Conn.put_req_header("authorization", "bearer: " <> token)}
  end

  test "admins can create accounts", %{conn: conn} do
    # req = conn |> api_v1_account_path(:create, %{"account" => %{name: name}})
    # conn |> post(req)
  end

  test "should return 400 if missing data in params", %{conn: conn, account: account} do
    req = conn |> api_v1_account_path(:create, %{})
    conn |> post(req) |> response(400)
  end
end
