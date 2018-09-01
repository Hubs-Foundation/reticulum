defmodule Ret.AccountTest do
  use Ret.DataCase

  alias Ret.{Account}

  test "create new account based on email" do
    account = Account.account_for_email("test@mozilla.com")
    assert account.login.identifier_hash == Ret.Crypto.hash("test@mozilla.com")
  end

  test "re-use same account when queried twice, case-insensitive" do
    account = Account.account_for_email("test@mozilla.com")
    account2 = Account.account_for_email("TEST@mozilla.com")

    assert account.account_id == account2.account_id
    assert account.login.login_id == account2.login.login_id
  end
end
