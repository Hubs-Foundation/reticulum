defmodule RetWeb.ApiInternal.V1.LoginEmailController do
  use RetWeb, :controller

  def update(conn, %{"old_email" => old_email, "new_email" => new_email}) do
    case Ret.change_email_for_login(%{old_email: old_email, new_email: new_email}) do
      :ok ->
        json(conn, %{success: true})

      {:error, reason} ->
        conn
        |> put_status(status_code_for_error(reason))
        |> json(%{error: reason})
    end
  end

  defp status_code_for_error(:new_email_already_in_use), do: :conflict
  defp status_code_for_error(:no_account_for_old_email), do: :not_found
  defp status_code_for_error(:invalid_parameters), do: :bad_request
  defp status_code_for_error(_), do: :internal_server_error
end
