defmodule Ret.AccountTest do
  use Ret.DataCase

  alias Ret.{Account}

  test "create new account based on email" do
    account = Account.find_or_create_account_for_email("test@mozilla.com")
    assert account.login.identifier_hash == Ret.Crypto.hash("test@mozilla.com")
  end

  test "ensure the admin account, but not subsequent accounts, are admins" do
    account = Account.find_or_create_account_for_email("admin@mozilla.com")
    account2 = Account.find_or_create_account_for_email("test2@mozilla.com")
    account3 = Account.find_or_create_account_for_email("test3@mozilla.com")
    assert account.is_admin === true
    assert account2.is_admin === false
    assert account3.is_admin === false
  end

  test "re-use same account when queried twice, case-insensitive" do
    account = Account.find_or_create_account_for_email("test@mozilla.com")
    account2 = Account.find_or_create_account_for_email("TEST@mozilla.com")

    assert account.account_id == account2.account_id
    assert account.login.login_id == account2.login.login_id
  end
end
