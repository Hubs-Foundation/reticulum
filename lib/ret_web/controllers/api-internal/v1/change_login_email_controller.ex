defmodule RetWeb.ApiInternal.V1.ChangeLoginEmailController do
  use RetWeb, :controller

  alias Ret.Login

  def post(conn, %{"old_email" => old_email, "new_email" => new_email})
  when is_binary(old_email) and is_binary(new_email) do
    conn = put_resp_header(conn, "content-type", "application/json")

    with false <- is_empty_or_whitespace(old_email),
         false <- is_empty_or_whitespace(new_email),
           true <- is_valid_email_address(old_email),
           true <- is_valid_email_address(new_email),
         :ok <- Login.update_identifier_hash(%{old_email: old_email, new_email: new_email}) do
      send_resp(conn, 200, %{success: true} |> Poison.encode!())
    else

      {:error, :new_email_already_in_use} ->
        send_resp(conn, 409, %{error: :new_email_already_in_use} |> Poison.encode!())

      {:error, :no_account_for_old_email } ->
        send_resp(conn, 409, %{error: :no_account_for_old_email} |> Poison.encode!())

      {:error, _ } ->
        send_resp(conn, 500, %{error: :failed_to_update_email} |> Poison.encode!())
    end
  end

  defp is_empty_or_whitespace(str) do
    String.trim(str) === ""
  end

  defp is_valid_email_address(_str) do
    # TODO
    true
  end
end
