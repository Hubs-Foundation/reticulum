defmodule RetWeb.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller
  import RetWeb.ErrorHelpers

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
end
