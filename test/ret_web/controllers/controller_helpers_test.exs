defmodule RetWeb.ControllerHelpersTest do
  use ExUnit.Case, async: true

  alias RetWeb.ControllerHelpers

  describe "extract_our_code_location/1" do
    test "extracts location from a project module" do
      stacktrace = [
        {RetWeb.ControllerHelpers, :extract_our_code_location, 1,
         [file: ~c"lib/ret_web/controllers/controller_helpers.ex", line: 25]}
      ]

      assert {"controller_helpers.ex", 25, :unknown} ==
               ControllerHelpers.extract_our_code_location(stacktrace)
    end

    test "ignores dependency modules and finds project module" do
      stacktrace = [
        {Plug.Conn, :send_resp, 3, [file: ~c"deps/plug/lib/plug/conn.ex", line: 400]},
        {RetWeb.ControllerHelpers, :render_error_json, 3,
         [file: ~c"lib/ret_web/controllers/controller_helpers.ex", line: 6]}
      ]

      assert {"controller_helpers.ex", 6, :send_resp} ==
               ControllerHelpers.extract_our_code_location(stacktrace)
    end

    test "falls back to the first entry if no project module is found" do
      stacktrace = [
        {Plug.Conn, :send_resp, 3, [file: ~c"deps/plug/lib/plug/conn.ex", line: 400]},
        {Phoenix.Controller, :render, 3,
         [file: ~c"deps/phoenix/lib/phoenix/controller.ex", line: 100]}
      ]

      assert {"conn.ex", 400, :unknown} ==
               ControllerHelpers.extract_our_code_location(stacktrace)
    end

    test "handles stacktrace with charlist paths (standard in Erlang/Elixir)" do
      stacktrace = [
        {RetWeb.SomeModule, :some_func, 0, [file: ~c"lib/ret_web/some_module.ex", line: 10]}
      ]

      assert {"some_module.ex", 10, :unknown} ==
               ControllerHelpers.extract_our_code_location(stacktrace)
    end

    test "handles malformed stacktrace entries by returning unknown" do
      # This should trigger the rescue block because of the pattern match
      stacktrace = [
        {:not, :a, :standard, :entry}
      ]

      assert {"<unknown>", 0} ==
               ControllerHelpers.extract_our_code_location(stacktrace)
    end

    test "handles empty stacktrace" do
      assert {"<unknown>", 0} ==
               ControllerHelpers.extract_our_code_location([])
    end

    test "detects project module even if it is not the first one" do
      stacktrace = [
        {SomeOther.Module, :func, 0, [file: ~c"lib/other.ex", line: 1]},
        {RetWeb.ControllerHelpers, :func, 0,
         [file: ~c"lib/ret_web/controller_helpers.ex", line: 2]}
      ]

      # SomeOther.Module does not start with Elixir.Ret
      assert {"controller_helpers.ex", 2, :func} ==
               ControllerHelpers.extract_our_code_location(stacktrace)
    end
  end
end
