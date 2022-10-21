defmodule RetWeb.ApiInternal.V1.ChangeLoginEmailController do
  use RetWeb, :controller

  alias Ret.ChangeEmailForLogin
  alias Plug.Conn.Status

  def post(conn, %{"old_email" => old_email, "new_email" => new_email})
      when is_binary(old_email) and is_binary(new_email) do
    case ChangeEmailForLogin.change_email_for_login(%{old_email: old_email, new_email: new_email}) do
      :ok ->
        conn
        |> put_status(Status.code(:ok))
        |> json(%{success: true})

      {:error, reason} ->
        conn
        |> put_status(status_code_for_error(reason))
        |> json(%{error: reason})
    end
  end

  defp status_code_for_error(:new_email_already_in_use) do
    Status.code(:conflict)
  end

  defp status_code_for_error(:no_account_for_old_email) do
    Status.code(:not_found)
  end

  defp status_code_for_error(:invalid_parameters) do
    Status.code(:bad_request)
  end

  defp status_code_for_error(:failed_to_update_login) do
    Status.code(:internal_server_error)
  end
end
