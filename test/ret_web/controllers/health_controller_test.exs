defmodule RetWeb.HealthControllerTest do
  use RetWeb.ConnCase

  import ExUnit.CaptureLog
  require Logger

  test "GET /health returns 500 and logs error inspection when a check fails", %{conn: conn} do
    log =
      capture_log([level: :error], fn ->
        # Cachex and RoomAssigner aren't mocked so this will fail.
        resp = conn |> get("/health")
        assert resp.status === 500
        assert resp.resp_body === "error"
      end)

    assert log =~ "Error"
  end
end
