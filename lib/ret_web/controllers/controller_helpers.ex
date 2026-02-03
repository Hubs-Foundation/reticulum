defmodule RetWeb.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller
  import RetWeb.ErrorHelpers
  require Logger

  def render_error_json(conn, status, params) do
    conn
    |> put_status(status)
    |> put_layout(false)
    |> put_view(RetWeb.ErrorView)
    |> render("error.json", %{error: params})
  end

  def render_error_json(conn, %Ecto.Changeset{} = changeset) do
    errors = Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    render_error_json(conn, 422, errors)
  end

  def render_error_json(conn, status) do
    code = Plug.Conn.Status.code(status)
    reason = Plug.Conn.Status.reason_phrase(code)
    render_error_json(conn, status, reason)
  end

  def log_our_code_location(stacktrace, error, description \\ "Failure") do
    {filename, line, function} =
      try do
        ind =
          Enum.find_index(stacktrace, fn
            {module, _function, _arity, [file: filepath, line: _line]} ->
              filepath = List.to_string(filepath)

              is_not_dependency =
                !String.contains?(filepath, "/deps/") && !String.contains?(filepath, "deps/")

              is_reticulum_module = String.starts_with?(to_string(module), "Elixir.Ret")
              is_not_dependency && is_reticulum_module

            # if stacktrace entry isn't in usual format, skips it
            _ ->
              false
              # if no matching entry found, returns first entry
          end) || 0

        {_module, _function, _arity, [file: filepath, line: line]} = Enum.at(stacktrace, ind)
        filename = Path.basename(List.to_string(filepath))

        function =
          if ind > 0 do
            {_mod, function, _ar, [_fil, _lin]} = Enum.at(stacktrace, ind - 1)
            function
          else
            :unknown
          end

        {filename, line, function}
      rescue
        _coding_error ->
          {"<unknown>", 0, :unknown}
      end

    Logger.error("#{description} at #{filename}:#{line} calling #{function}: #{inspect(error)}")

    {filename, line, function}
  end
end
