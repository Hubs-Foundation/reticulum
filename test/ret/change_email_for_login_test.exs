defmodule Ret.ChangeEmailForLoginTest do
  use Ret.DataCase
  alias Ret.Account

  @alpha "alpha@example.com"
  @bravo "bravo@example.org"

  describe "change email for login" do
    test "validates the new email address" do
      Account.find_or_create_account_for_email(@alpha)

      {:error, :invalid_parameters} =
        Ret.change_email_for_login(%{new_email: "not_an_email_address", old_email: @alpha})

      refute Account.exists_for_email?("not_an_email_address")
      assert Account.exists_for_email?(@alpha)
    end

    test "changes the account email" do
      Account.find_or_create_account_for_email(@alpha)
      :ok = Ret.change_email_for_login(%{new_email: @bravo, old_email: @alpha})
      refute Account.exists_for_email?(@alpha)
      assert Account.exists_for_email?(@bravo)
    end

    test "validates that the new email cannot already be in use" do
      Account.find_or_create_account_for_email(@alpha)
      Account.find_or_create_account_for_email(@bravo)

      {:error, :new_email_already_in_use} = Ret.change_email_for_login(%{new_email: @bravo, old_email: @alpha})
    end

    test "validates that the old email is in use" do
      {:error, :no_account_for_old_email} = Ret.change_email_for_login(%{new_email: @bravo, old_email: @alpha})
    end
  end
end
