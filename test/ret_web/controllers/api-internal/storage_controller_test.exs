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
    mock_storage_used(0)
    resp = request_storage(conn)
    assert resp["storage_mb"] === 0.0

    mock_storage_used(10)
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

  test "storage endpoint errors when storage usage is not available", %{conn: conn} do
    mock_storage_used(nil)
    resp = request_storage(conn, expected_status: 503)
    assert resp["error"] === "storage_usage_unavailable"
  end

  # The Ret.Storage module relies on a cached value to retrieve storage usage via Ret.StorageUsed.
  # Since we mainly care about testing the endpoint here, we use the cache to mock the usage value
  # and ensure that the endpoint returns it as expected.
  defp mock_storage_used(nil), do: Cachex.put(:storage_used, :storage_used, nil)
  defp mock_storage_used(storage_used_mb), do: Cachex.put(:storage_used, :storage_used, storage_used_mb * 1024)

  defp request_storage(conn, opts \\ [expected_status: 200]) do
    conn
    |> put_req_header(@dashboard_access_header, @dashboard_access_key)
    |> get("/api-internal/v1/storage")
    |> json_response(opts[:expected_status])
  end
end
