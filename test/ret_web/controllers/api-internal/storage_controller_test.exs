defmodule RetWeb.ApiInternal.V1.StorageControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  @dashboard_access_header "x-ret-dashboard-access-key"
  @dashboard_access_key "test-key"

  setup_all do
    merge_module_config(:ret, RetWeb.Plugs.DashboardHeaderAuthorization, %{dashboard_access_key: @dashboard_access_key})

    on_exit(fn ->
      Ret.TestHelpers.merge_module_config(:ret, RetWeb.Plugs.DashboardHeaderAuthorization, %{dashboard_access_key: nil})
    end)
  end

  test "storage endpoint responds with cached storage value", %{conn: conn} do
    # The Ret.Storage module relies on a cached value to retrieve storage usage via Ret.StorageUsed.
    # Since we mainly care about testing the endpoint here, we use the cache to mock the usage value
    # and ensure that the endpoint returns it as expected.
    Cachex.put(:storage_used, :storage_used, 0)
    resp = request_storage(conn)
    assert resp["storage_mb"] === 0.0

    Cachex.put(:storage_used, :storage_used, 10 * 1024)
    resp = request_storage(conn)
    assert resp["storage_mb"] === 10.0
  end

  test "storage endpoint errors without correct access key", %{conn: conn} do
    resp = get(conn, "/api-internal/v1/storage")
    assert resp.status === 401

    resp =
      conn
      |> put_req_header(@dashboard_access_header, "incorrect-access-key")
      |> get("/api-internal/v1/storage")

    assert resp.status === 401
  end

  defp request_storage(conn) do
    conn
    |> put_req_header(@dashboard_access_header, @dashboard_access_key)
    |> get("/api-internal/v1/storage")
    |> json_response(200)
  end
end
