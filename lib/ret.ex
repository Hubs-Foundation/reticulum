defmodule Ret do
  @moduledoc """
  Ret keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  alias Ret.{Account, Login, Repo}

  def change_email_for_login(%{old_email: old_email, new_email: new_email}) do
    if not valid_email_address?(new_email) do
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
    |> Ecto.Changeset.change(identifier_hash: Account.identifier_hash_for_email(new_email))
    |> Ecto.Changeset.unique_constraint(:identifier_hash)
    |> Repo.update()
    |> case do
      {:error, %Ecto.Changeset{errors: [identifier_hash: {_, [{:constraint, :unique}, _]}]}} ->
        {:error, :new_email_already_in_use}

      {:error, _} ->
        {:error, :failed_to_update_login}

      {:ok, _} ->
        :ok
    end
  end

  defp valid_email_address?(string) do
    string =~ ~r/\S+@\S+/
  end
end
