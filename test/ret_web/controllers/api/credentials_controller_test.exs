defmodule RetWeb.CredentialsControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers, only: [create_account: 2, put_auth_header_for_account: 2]
  alias Ret.AppConfig
  alias Ret.Api.Scopes

  @endpoint RetWeb.Endpoint

  setup %{conn: conn} do
    AppConfig.set_config_value("features|public_api_access", true)

    {
      :ok,
      conn: conn,
      account: create_account("nonadmin", false),
      admin_account: create_account("admin", true),
      list: credentials_path(conn, :index, []),
      create: credentials_path(conn, :create)
    }
  end

  defp valid_scopes() do
    [Scopes.read_rooms(), Scopes.write_rooms()]
  end

  defp params(scopes, subject_type) do
    [scopes: scopes, subject_type: subject_type]
  end

  defp get_credentials_count(conn, account) do
    conn
    |> put_auth_header_for_account(account)
    |> get(credentials_path(conn, :index, []))
    |> json_response(200)
    |> Map.get("credentials")
    |> Enum.count()
  end

  defp create_credentials_for_another_account(conn, creator_account, account) do
    conn
    |> put_auth_header_for_account(creator_account)
    |> post(
      credentials_path(conn, :create),
      params(valid_scopes(), :account) ++ [account_id: account.account_id]
    )
  end

  test "Accounts must authenticate to access credentials API.", %{
    account: account,
    admin_account: admin_account,
    conn: conn,
    list: list,
    create: create
  } do
    conn
    |> put_auth_header_for_account(account)
    |> get(list)
    |> json_response(200)

    conn |> get(list) |> response(401)

    conn
    |> put_auth_header_for_account(admin_account)
    |> post(create, params(valid_scopes(), :account))
    |> json_response(200)

    conn |> post(create, params(valid_scopes(), :account)) |> response(401)
  end

  test "Account credentials can be created and listed", %{
    admin_account: admin_account,
    conn: conn,
    create: create
  } do
    assert get_credentials_count(conn, admin_account) === 0

    conn
    |> put_auth_header_for_account(admin_account)
    |> post(create, params(valid_scopes(), :account))
    |> json_response(200)

    assert get_credentials_count(conn, admin_account) === 1
  end

  test "Admins accounts can create credentials on behalf of other accounts", %{
    account: account,
    admin_account: admin_account,
    conn: conn
  } do
    assert get_credentials_count(conn, account) === 0

    create_credentials_for_another_account(conn, admin_account, account)
    |> json_response(200)

    assert get_credentials_count(conn, account) === 1
  end

  test "Non-admins cannot create credentials on behalf of other accounts", %{
    account: account,
    conn: conn
  } do
    another_account = create_account("another_account", false)

    assert get_credentials_count(conn, another_account) === 0

    create_credentials_for_another_account(conn, account, another_account)
    |> json_response(401)

    assert get_credentials_count(conn, another_account) === 0
  end

  test "App credentials can be created and listed", %{
    admin_account: admin_account,
    conn: conn,
    create: create
  } do
    assert get_credentials_count(conn, admin_account) === 0

    conn
    |> put_auth_header_for_account(admin_account)
    |> post(create, params(valid_scopes(), :app))
    |> json_response(200)

    assert get_credentials_count(conn, admin_account) === 1
  end

  test "Account must be admin to manage app credentials", %{
    admin_account: admin_account,
    account: account,
    conn: conn,
    list: list,
    create: create
  } do
    conn
    |> put_auth_header_for_account(account)
    |> get(list, app: true)
    |> response(401)

    conn
    |> put_auth_header_for_account(admin_account)
    |> get(list, app: true)
    |> json_response(200)

    conn
    |> put_auth_header_for_account(account)
    |> post(create, params(valid_scopes(), :app))
    |> response(401)

    conn
    |> put_auth_header_for_account(admin_account)
    |> post(create, params(valid_scopes(), :app))
    |> json_response(200)
  end

  test "Scopes and subject types must be valid", %{
    admin_account: admin_account,
    conn: conn,
    create: create
  } do
    errors =
      conn
      |> put_auth_header_for_account(admin_account)
      |> post(
        create,
        params([:not_a_valid_scope, :another_invalid_scope], :not_a_valid_subject_type)
      )
      |> json_response(400)
      |> Map.get("errors")

    assert Enum.at(errors, 0)["failure_type"] == "invalid_scope"
    assert Enum.at(errors, 1)["failure_type"] == "invalid_scope"
    assert Enum.at(errors, 2)["failure_type"] == "invalid_subject_type"
  end

  test "Credentials omit the token in all but the first response", %{
    admin_account: admin_account,
    conn: conn,
    list: list,
    create: create
  } do
    refute conn
           |> put_auth_header_for_account(admin_account)
           |> post(create, params(valid_scopes(), :account))
           |> json_response(200)
           |> Map.get("credentials")
           |> hd()
           |> Map.get("token")
           |> is_nil()

    assert conn
           |> put_auth_header_for_account(admin_account)
           |> get(list)
           |> json_response(200)
           |> Map.get("credentials")
           |> hd()
           |> Map.get("token")
           |> is_nil()
  end

  test "Accounts can revoke their own credentials", %{
    admin_account: admin_account,
    account: account,
    conn: conn
  } do
    creds =
      conn
      |> create_credentials_for_another_account(admin_account, account)
      |> json_response(200)
      |> Map.get("credentials")
      |> hd()

    refute Map.get(creds, "is_revoked")

    assert conn
           |> put_auth_header_for_account(account)
           |> patch(credentials_path(conn, :update, Map.get(creds, "id"), revoke: true))
           |> json_response(200)
           |> Map.get("credentials")
           |> hd()
           |> Map.get("is_revoked")
  end

  test "Non-admins cannot revoke credentials they do not own", %{
    admin_account: admin_account,
    account: account,
    conn: conn
  } do
    another_account = create_account("another_account", false)

    creds =
      conn
      |> create_credentials_for_another_account(admin_account, another_account)
      |> json_response(200)
      |> Map.get("credentials")
      |> hd()

    refute Map.get(creds, "is_revoked")

    sid = Map.get(creds, "id")

    assert conn
           |> put_auth_header_for_account(account)
           |> patch(credentials_path(conn, :update, sid, revoke: true))
           |> json_response(401)

    refute conn
           |> put_auth_header_for_account(another_account)
           |> get(credentials_path(conn, :show, sid))
           |> json_response(200)
           |> Map.get("credentials")
           |> hd()
           |> Map.get("is_revoked")

    assert conn
           |> put_auth_header_for_account(another_account)
           |> patch(credentials_path(conn, :update, sid, revoke: true))
           |> json_response(200)
           |> Map.get("credentials")
           |> hd()
           |> Map.get("is_revoked")
  end

  test "Admins can revoke any credentials", %{
    admin_account: admin_account,
    account: account,
    conn: conn,
    create: create
  } do
    another_admin_account = create_account("another_admin", true)

    # Admins can revoke app tokens they do not own
    creds =
      conn
      |> put_auth_header_for_account(another_admin_account)
      |> post(create, params(valid_scopes(), :app))
      |> json_response(200)
      |> Map.get("credentials")
      |> hd()

    refute Map.get(creds, "is_revoked")

    assert conn
           |> put_auth_header_for_account(admin_account)
           |> patch(credentials_path(conn, :update, Map.get(creds, "id"), revoke: true))
           |> json_response(200)
           |> Map.get("credentials")
           |> hd()
           |> Map.get("is_revoked")

    # Admins can revoke account tokens they do not own
    creds =
      conn
      |> create_credentials_for_another_account(another_admin_account, account)
      |> json_response(200)
      |> Map.get("credentials")
      |> hd()

    refute Map.get(creds, "is_revoked")

    assert conn
           |> put_auth_header_for_account(admin_account)
           |> patch(credentials_path(conn, :update, Map.get(creds, "id"), revoke: true))
           |> json_response(200)
           |> Map.get("credentials")
           |> hd()
           |> Map.get("is_revoked")
  end

  test "Public API Access has to be enabled on the server", %{
    account: account,
    conn: conn,
    list: list
  } do
    AppConfig.set_config_value("features|public_api_access", false)

    conn
    |> put_auth_header_for_account(account)
    |> get(list)
    |> response(404)

    AppConfig.set_config_value("features|public_api_access", true)

    conn
    |> put_auth_header_for_account(account)
    |> get(list)
    |> json_response(200)
  end
end
