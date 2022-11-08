defmodule RetWeb.ApiInternal.V1.LoginEmailControllerTest do
  use RetWeb.ConnCase

  import Ret.TestHelpers
  alias Ret.Account

  @dashboard_access_header "x-ret-dashboard-access-key"
  @dashboard_access_key "test-key"

  setup_all do
    merge_module_config(:ret, RetWeb.Plugs.DashboardHeaderAuthorization, %{dashboard_access_key: @dashboard_access_key})

    on_exit(fn ->
      merge_module_config(:ret, RetWeb.Plugs.DashboardHeaderAuthorization, %{dashboard_access_key: nil})
    end)
  end

  describe "PUT update" do
    test "validates the new email address", %{conn: conn} do
      Account.find_or_create_account_for_email("alice@reticulum.io")
      assert %{status: 400} = put_change_email_for_login(conn, "not_an_email_address", "alice@reticulum.io")
      refute Account.exists_for_email?("not_an_email_address")
      assert Account.exists_for_email?("alice@reticulum.io")
    end

    test "changes the account email", %{conn: conn} do
      Account.find_or_create_account_for_email("alice@reticulum.io")
      assert %{status: 200} = put_change_email_for_login(conn, "alicia@anotherdomain.com", "alice@reticulum.io")
      refute Account.exists_for_email?("alice@reticulum.io")
      assert Account.exists_for_email?("alicia@anotherdomain.com")
    end

    test "validates that the new email cannot already be in use", %{conn: conn} do
      Account.find_or_create_account_for_email("alice@reticulum.io")
      Account.find_or_create_account_for_email("bob@reticulum.io")
      assert %{status: 409} = put_change_email_for_login(conn, "bob@reticulum.io", "alice@reticulum.io")
    end

    test "validates that the old email is in use", %{conn: conn} do
      assert %{status: 404} = put_change_email_for_login(conn, "bob@reticulum.io", "alice@reticulum.io")
    end

    test "authenticates the request", %{conn: conn} do
      Account.find_or_create_account_for_email("alice@reticulum.io")

      assert %{status: 401} =
               conn
               |> put("/api-internal/v1/change_email_for_login", %{
                 "old_email" => "alice@reticulum.io",
                 "new_email" => "bob@reticulum.io"
               })

      assert Account.exists_for_email?("alice@reticulum.io")
      refute Account.exists_for_email?("bob@reticulum.io")
    end
  end

  defp put_change_email_for_login(conn, new_email, old_email) do
    conn
    |> put_req_header(@dashboard_access_header, @dashboard_access_key)
    |> put("/api-internal/v1/change_email_for_login", %{"old_email" => old_email, "new_email" => new_email})
  end
end
