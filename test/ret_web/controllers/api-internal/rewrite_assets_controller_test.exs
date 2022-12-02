defmodule RetWeb.ApiInternal.V1.RewriteAssetsControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  @dashboard_access_header "x-ret-dashboard-access-key"
  @dashboard_access_key "test-key"

  setup_all do
    merge_module_config(:ret, RetWeb.Plugs.DashboardHeaderAuthorization, %{
      dashboard_access_key: @dashboard_access_key
    })

    on_exit(fn ->
      Ret.TestHelpers.merge_module_config(:ret, RetWeb.Plugs.DashboardHeaderAuthorization, %{
        dashboard_access_key: nil
      })
    end)
  end

  test "errors with invalid domains", %{conn: conn} do
    assert %{status: 500} = post_rewrite_assets(conn, "foo", " ")
    assert %{status: 500} = post_rewrite_assets(conn, "foo", "")
    assert %{status: 500} = post_rewrite_assets(conn, " ", "foo")
    assert %{status: 500} = post_rewrite_assets(conn, "", "foo")
    assert %{status: 500} = post_rewrite_assets(conn, "https://foo", "foo")
    assert %{status: 500} = post_rewrite_assets(conn, "foo", "https://foo")
  end

  test "succeeds with valid domains", %{conn: conn} do
    assert %{status: 200} = post_rewrite_assets(conn, "foo", "bar")
  end

  defp post_rewrite_assets(conn, new_domain, old_domain) do
    conn
    |> put_req_header(@dashboard_access_header, @dashboard_access_key)
    |> post("/api-internal/v1/rewrite_assets", %{
      "old_domain" => old_domain,
      "new_domain" => new_domain
    })
  end
end
