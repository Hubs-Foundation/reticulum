defmodule RetWeb.HealthControllerTest do
  use RetWeb.ConnCase

  import ExUnit.CaptureLog
  require Logger

  @tag :error_logging
  test "GET /health, when a check fails, returns 500 and logs error & location", %{conn: conn} do
    log =
      capture_log([level: :error], fn ->
        # Cachex and RoomAssigner aren't mocked so this will fail.
        resp = conn |> get("/health")
        assert resp.status === 500
        assert resp.resp_body === "error"
      end)

    # It should log health_controller.ex (reticulum code) even if the error
    # occurs inside a library (like Enum or Cachex).
    assert log =~ "Health check failed"
    assert log =~ "at health_controller.ex:13"
    assert log =~ "calling Enum.count"
  end
end
