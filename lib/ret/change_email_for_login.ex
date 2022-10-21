defmodule Ret.ChangeEmailForLogin do
  import Ecto.Changeset
  alias Ret.{Account, Login, Repo}
  alias Ecto.Changeset

  def change_email_for_login(%{old_email: old_email, new_email: new_email} = _) do
    if empty_or_whitespace?(old_email) or not valid_email_address?(new_email) do
      {:error, :invalid_parameters}
    else
      change_email_for_login(
        Repo.get_by(Login, identifier_hash: Account.identifier_hash_for_email(old_email)),
        new_email
      )
    end
  end

  defp change_email_for_login(nil, _new_email) do
    {:error, :no_account_for_old_email}
  end

  defp change_email_for_login(%Login{} = login, new_email) do
    login
    |> change(identifier_hash: Account.identifier_hash_for_email(new_email))
    |> unique_constraint(:identifier_hash)
    |> Repo.update()
    |> case do
      {:error, %Changeset{errors: [identifier_hash: {_, [{:constraint, :unique}, _]}]}} ->
        {:error, :new_email_already_in_use}

      {:error, _} ->
        {:error, :failed_to_update_login}

      {:ok, _} ->
        :ok
    end
  end

  defp empty_or_whitespace?(string) do
    String.trim(string) === ""
  end

  defp valid_email_address?(string) do
    string =~ ~r/\S+@\S+/
  end
end
