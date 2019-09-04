defmodule Ret.GuardianTest do
  use Ret.DataCase

  alias Ecto.{Changeset}
  alias Ret.{Account, Guardian, Repo}

  test "retrieve account from token" do
    account = Account.account_for_email("test@mozilla.com")
    token = Account.credentials_for_identifier_hash(account.login.identifier_hash)

    {:ok, account2, _claims} = Guardian.resource_from_token(token)

    assert account.account_id == account2.account_id
  end

  test "does not retrieve account from revoked token" do
    account = Account.account_for_email("test@mozilla.com")
    token = Account.credentials_for_identifier_hash(account.login.identifier_hash)

    date = Timex.now() |> Timex.shift(seconds: 1) |> DateTime.truncate(:second)

    account |> Changeset.change(%{min_token_issued_at: date}) |> Repo.update()

    {:error, "Not found"} = Guardian.resource_from_token(token)
  end
end
