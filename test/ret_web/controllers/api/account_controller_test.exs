defmodule RetWeb.AccountControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  alias Ret.{Account}

  setup %{conn: conn} do
    {:ok, admin_account: admin_account} = create_admin_account("test")
    {:ok, token, _params} = admin_account |> Ret.Guardian.encode_and_sign()

    {:ok,
     account: admin_account,
     conn: conn |> Plug.Conn.put_req_header("authorization", "bearer: " <> token)}
  end

  test "non-admins cannot create accounts", %{conn: conn} do
    account = create_random_account()
    {:ok, token, _params} = account |> Ret.Guardian.encode_and_sign()
    conn = conn |> Plug.Conn.put_req_header("authorization", "bearer: " <> token)
    req = conn |> api_v1_account_path(:create, %{data: %{email: "testapi@hubsfoundation.org"}})
    conn = conn |> post(req)

    assert !Account.exists_for_email?("testapi@hubsfoundation.org")
    assert conn.status === 401
    assert conn.resp_body === "Not authorized"
  end

  test "admins can create accounts", %{conn: conn} do
    req = conn |> api_v1_account_path(:create, %{data: %{email: "testapi@hubsfoundation.org"}})
    res = conn |> post(req) |> response(200) |> Poison.decode!()

    account = Account.account_for_email("testapi@hubsfoundation.org")

    assert account
    assert res["data"]["id"] === "#{account.account_id}"
    assert res["data"]["login"]["email"] === "testapi@hubsfoundation.org"
  end

  test "admins can create accounts with identities", %{conn: conn} do
    req =
      conn
      |> api_v1_account_path(:create, %{
        data: %{email: "testapi@hubsfoundation.org", name: "Test User"}
      })

    res = conn |> post(req) |> response(200) |> Poison.decode!()

    account = Account.account_for_email("testapi@hubsfoundation.org")

    assert account
    assert res["data"]["id"] === "#{account.account_id}"
    assert res["data"]["login"]["email"] === "testapi@hubsfoundation.org"
    assert res["data"]["identity"]["name"] === "Test User"
  end

  test "admins can patch account identities", %{conn: conn} do
    create_account("testapi")
    create_account("testapi2")

    conn
    |> put_req_header("content-type", "application/json")
    |> patch(
      "/api/v1/accounts",
      Poison.encode!(%{
        data: [
          %{email: "testapi@hubsfoundation.org", name: "Test User New"},
          %{email: "testapi2@hubsfoundation.org", name: "Test User 2 New"}
        ]
      })
    )
    |> response(207)

    account = Account.account_for_email("testapi@hubsfoundation.org")
    assert account.identity.name === "Test User New"

    account = Account.account_for_email("testapi2@hubsfoundation.org")
    assert account.identity.name === "Test User 2 New"
  end

  test "admins can create multiple acounts, and have validation errors", %{conn: conn} do
    req =
      conn
      |> api_v1_account_path(:create, %{
        data: [
          %{email: "testapi1@hubsfoundation.org"},
          %{email: "testapi2@hubsfoundation.org"},
          %{email: "invalidemail"}
        ]
      })

    res = conn |> post(req) |> response(207) |> Poison.decode!()

    account1 = Account.account_for_email("testapi1@hubsfoundation.org")
    account2 = Account.account_for_email("testapi2@hubsfoundation.org")
    result1 = res |> Enum.at(0)
    result2 = res |> Enum.at(1)
    result3 = res |> Enum.at(2)

    assert account1
    assert account2
    assert result1["status"] === 200
    assert result1["body"]["data"]["id"] === "#{account1.account_id}"
    assert result1["body"]["data"]["login"]["email"] === "testapi1@hubsfoundation.org"
    assert result2["status"] === 200
    assert result2["body"]["data"]["id"] === "#{account2.account_id}"
    assert result2["body"]["data"]["login"]["email"] === "testapi2@hubsfoundation.org"
    assert result3["status"] === 400
    assert result3["body"]["errors"] |> Enum.at(0) |> Map.get("code") === "MALFORMED_RECORD"
  end

  test "should return 400 if email is invalid", %{conn: conn} do
    req = conn |> api_v1_account_path(:create, %{data: %{email: "invalidemail"}})
    conn |> post(req) |> response(400)
  end

  test "should return 400 if missing data in params", %{conn: conn} do
    req = conn |> api_v1_account_path(:create, %{})
    conn |> post(req) |> response(400)
  end

  test "should return 400 if data is malformed", %{conn: conn} do
    req = conn |> api_v1_account_path(:create, %{data: 123})
    conn |> post(req) |> response(400)
  end

  test "should return 400 if email is missing on root record", %{conn: conn} do
    req = conn |> api_v1_account_path(:create, %{data: %{}})
    conn |> post(req) |> response(400)
  end

  test "should return 409 if account exists", %{conn: conn} do
    req = conn |> api_v1_account_path(:create, %{data: %{email: "test@hubsfoundation.org"}})
    conn |> post(req) |> response(409)
  end

  test "non-admins cannot search for accounts", %{conn: conn} do
    account = create_random_account()
    {:ok, token, _params} = account |> Ret.Guardian.encode_and_sign()
    conn = conn |> Plug.Conn.put_req_header("authorization", "bearer: " <> token)
    req = conn |> api_v1_account_search_path(:create, %{email: "unknown@hubsfoundation.org"})
    conn = conn |> post(req)

    assert conn.status === 401
    assert conn.resp_body === "Not authorized"
  end

  test "should return 404 if no such account exists", %{conn: conn} do
    req = conn |> api_v1_account_search_path(:create, %{email: "unknown@hubsfoundation.org"})
    conn = conn |> post(req)

    assert conn.status === 404
  end

  test "should return account if account exists", %{conn: conn} do
    req = conn |> api_v1_account_search_path(:create, %{email: "test@hubsfoundation.org"})
    res = conn |> post(req) |> response(200) |> Poison.decode!()

    account = Account.account_for_email("test@hubsfoundation.org")
    record = res["data"] |> Enum.at(0)

    assert record["id"] === "#{account.account_id}"
  end
end
