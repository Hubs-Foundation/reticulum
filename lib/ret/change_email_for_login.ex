defmodule Ret.ChangeEmailForLogin do
  import Ecto.Changeset
  alias Ret.{Account, Login, Repo}
  alias Ecto.Changeset

  def change_email_for_login(%{old_email: old_email, new_email: new_email} = _) do
    change_email_for_login(Repo.get_by(Login, identifier_hash: Account.identifier_hash_for_email(old_email)), new_email)
  end

  defp change_email_for_login(nil, _new_email) do
    {:error, :no_account_for_old_email}
  end

  defp change_email_for_login(%Login{} = login, new_email) do
    login
    |> cast(%{identifier_hash: Account.identifier_hash_for_email(new_email)}, [:identifier_hash])
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
end
