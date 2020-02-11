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
    req = conn |> api_v1_account_path(:create, %{"data" => %{email: "testapi@mozilla.com"}})
    res = conn |> post(req) |> response(200)
    # assert Account.account_for_email("testapi@mozilla.com")
  end

  test "should return 400 if email is invalid", %{conn: conn} do
    req = conn |> api_v1_account_path(:create, %{"data" => %{email: "invalidemail"}})
    res = conn |> post(req) |> response(400)
  end

  test "should return 400 if missing data in params", %{conn: conn, account: account} do
    req = conn |> api_v1_account_path(:create, %{})
    conn |> post(req) |> response(400)
  end

  test "should return 400 if data is malformed", %{conn: conn, account: account} do
    req = conn |> api_v1_account_path(:create, %{"data" => 123})
    conn |> post(req) |> response(400)
  end

  test "should return 400 if email is missing on root record", %{conn: conn, account: account} do
    req = conn |> api_v1_account_path(:create, %{"data" => %{}})
    conn |> post(req) |> response(400)
  end

  test "should return 409 if account exists", %{conn: conn} do
    req = conn |> api_v1_account_path(:create, %{"data" => %{email: "test@mozilla.com"}})
    res = conn |> post(req) |> response(409)
  end
end
