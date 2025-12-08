defmodule Ret.AccountTest do
  use Ret.DataCase

  alias Ret.{Account}

  test "create new account based on email" do
    account = Account.find_or_create_account_for_email("test@hubsfoundation.org")
    assert account.login.identifier_hash == Ret.Crypto.hash("test@hubsfoundation.org")
  end

  test "ensure the admin account, but not subsequent accounts, are admins" do
    account = Account.find_or_create_account_for_email("admin@hubsfoundation.org")
    account2 = Account.find_or_create_account_for_email("test2@hubsfoundation.org")
    account3 = Account.find_or_create_account_for_email("test3@hubsfoundation.org")
    assert account.is_admin === true
    assert account2.is_admin === false
    assert account3.is_admin === false
  end

  test "re-use same account when queried twice, case-insensitive" do
    account = Account.find_or_create_account_for_email("test@hubsfoundation.org")
    account2 = Account.find_or_create_account_for_email("TEST@hubsfoundation.org")

    assert account.account_id == account2.account_id
    assert account.login.login_id == account2.login.login_id
  end

  test "can assign and re-assign identity" do
    account = Account.find_or_create_account_for_email("test@hubsfoundation.org")
    account = account |> Account.set_identity!("Test User")

    assert account.identity
    assert account.identity.name === "Test User"

    account = account |> Account.set_identity!("Test User 2")

    assert account.identity
    assert account.identity.name === "Test User 2"

    account = account |> Account.revoke_identity!()
    refute account.identity
  end
end
