defmodule RetTest do
  use Ret.DataCase
  import Ecto.Query, only: [from: 2]
  import Ret.TestHelpers
  alias Ret.{Account}

  describe "account deletion" do
    test "deletes account, login, identity, oauthproviders, and api_credentials" do
      {:ok, admin_account: admin_account} = create_admin_account("admin")
      test_account = create_account("test")

      Account.set_identity!(test_account, "test identity")

      %Ret.OAuthProvider{}
      |> Ecto.Changeset.change(source: :discord, account: test_account, provider_account_id: "discord-test-user")
      |> Ret.Repo.insert_or_update()

      Ret.Api.TokenUtils.gen_token_for_account(test_account)

      assert %Account{} = Ret.get_account_by_id(test_account.account_id)
      assert 1 === count(Ret.Login, test_account)
      assert 1 === count(Ret.Identity, test_account)
      assert 1 === count(Ret.OAuthProvider, test_account)
      assert 1 === count(Ret.Api.Credentials, test_account)

      assert :ok = Ret.delete_account(admin_account, test_account)

      assert nil === Ret.get_account_by_id(test_account.account_id)
      assert 0 === count(Ret.Login, test_account)
      assert 0 === count(Ret.Identity, test_account)
      assert 0 === count(Ret.OAuthProvider, test_account)
      assert 0 === count(Ret.Api.Credentials, test_account)
    end
  end

  defp count(queryable, account) do
    Ret.Repo.aggregate(
      from(record in queryable, where: record.account_id == ^account.account_id),
      :count
    )
  end
end
