defmodule Ret.GuardianTest do
  use Ret.DataCase

  alias Ecto.{Changeset}
  alias Ret.{Account, Guardian, Repo}

  test "retrieve account from token" do
    account = Account.find_or_create_account_for_email("test@hubsfoundation.org")
    token = account |> Account.credentials_for_account()

    {:ok, account2, _claims} = Guardian.resource_from_token(token)

    assert account.account_id == account2.account_id
  end

  test "avoid creation when looking up" do
    Account.account_for_email("test@hubsfoundation.org")
    refute Account.exists_for_email?("test@hubsfoundation.org")
  end

  test "does not retrieve account from revoked token" do
    account = Account.find_or_create_account_for_email("test@hubsfoundation.org")
    token = account |> Account.credentials_for_account()

    date = Timex.now() |> Timex.shift(seconds: 1) |> DateTime.truncate(:second)

    account |> Changeset.change(%{min_token_issued_at: date}) |> Repo.update()

    {:error, "Not found"} = Guardian.resource_from_token(token)
  end
end
