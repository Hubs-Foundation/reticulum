defmodule Ret.AccountContext do
  import Canada, only: [can?: 2]
  alias Ret.{Account, Repo}

  def get_account_by_id(account_id) do
    Repo.get(Account, account_id)
  end

  def delete_account(%Account{} = acting_account, %Account{} = account_to_delete) do
    if can?(acting_account, delete_account(account_to_delete)) do
      case Repo.delete(account_to_delete) do
        {:ok, _} -> :ok
        {:error, _} -> {:error, :failed}
      end
    else
      {:error, :forbidden}
    end
  end
end
