defmodule RetWeb.ApiInternal.V1.LoginEmailController do
  use RetWeb, :controller

  def update(conn, %{"old_email" => old_email, "new_email" => new_email}) do
    case Ret.change_email_for_login(%{old_email: old_email, new_email: new_email}) do
      :ok ->
        json(conn, %{success: true})

      {:error, reason} ->
        conn
        |> put_status(status_code_for_error()[reason] || :internal_server_error)
        |> json(%{error: reason})
    end
  end

  defp status_code_for_error() do
    [
      new_email_already_in_use: :conflict,
      no_account_for_old_email: :not_found,
      invalid_parameters: :bad_request
    ]
  end
end
