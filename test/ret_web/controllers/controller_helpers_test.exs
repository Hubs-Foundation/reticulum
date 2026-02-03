defmodule RetWeb.ControllerHelpersTest do
  use ExUnit.Case, async: true

  alias RetWeb.ControllerHelpers
  import ExUnit.CaptureLog
  require Logger

  describe "log_our_code_location/3" do
    test "ignores dependency modules and finds innermost project module" do
      log =
        capture_log([level: :error], fn ->
          stacktrace = [
            {Bamboo.Email, :new_email, 0,
             [file: ~c"_build/test/lib/bamboo/ebin/Elixir.Bamboo.Email.beam", line: 190]},
            {RetWeb.Email, :auth_email, 2, [file: ~c"lib/ret_web/email.ex", line: 19]},
            {RetWeb.Endpoint, :get_cors_origins, 0, [file: ~c"lib/ret_web/endpoint.ex", line: 10]}
          ]

          ControllerHelpers.log_our_code_location(stacktrace, :email_error, "Pseudo-failure")
        end)

      assert log =~ "Pseudo-failure"
      assert log =~ "at email.ex:19"
      assert log =~ "calling new_email"
      assert log =~ ":email_error"
    end

    test "falls back to the first entry if no project module is found" do
      log =
        capture_log([level: :error], fn ->
          stacktrace = [
            {Plug.Conn, :send_resp, 3, [file: ~c"deps/plug/lib/plug/spam.ex", line: 400]},
            {Phoenix.Controller, :render, 3,
             [file: ~c"deps/phoenix/lib/phoenix/controller.ex", line: 100]}
          ]

          ControllerHelpers.log_our_code_location(stacktrace, :another_error)
        end)

      assert log =~ "Failure"
      assert log =~ "at spam.ex:400"
      assert log =~ "calling unknown"
      assert log =~ ":another_error"
    end

    test "handles malformed stacktrace entries by returning unknown" do
      log =
        capture_log([level: :error], fn ->
          # This should trigger the rescue block because pattern doesn't match
          stacktrace = [
            {:not, :a, :standard, :entry}
          ]

          ControllerHelpers.log_our_code_location(stacktrace, :spam_error, "Probe failure")
        end)

      assert log =~ "Probe failure"
      assert log =~ "at <unknown>:0"
      assert log =~ "calling unknown"
      assert log =~ ":spam_error"
    end

    test "handles empty stacktrace by returning unknown" do
      log =
        capture_log([level: :error], fn ->
          # This should trigger the rescue block because there's no entry to match
          ControllerHelpers.log_our_code_location([], :strange_error, "Weird failure")
        end)

      assert log =~ "Weird failure"
      assert log =~ "at <unknown>:0"
      assert log =~ "calling unknown"
      assert log =~ ":strange_error"
    end
  end
end
