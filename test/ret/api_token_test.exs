defmodule Ret.ApiTokenTest do
  use Ret.DataCase

  alias Ret.{Crypto, Repo}
  alias Ret.Api.{TokenUtils, Credentials}

  test "Generating an api token puts it in the database" do
    {:ok, token, _claims} = TokenUtils.gen_app_token()
    expected_hash = Crypto.hash(token)

    %Credentials{token_hash: token_hash} =
      Repo.one(Credentials.query() |> Credentials.where_token_hash_is(expected_hash))

    assert expected_hash == token_hash
  end

  test "Api tokens can be revoked" do
    {:ok, token, _claims} = TokenUtils.gen_app_token()
    expected_hash = Crypto.hash(token)

    {:ok, %Credentials{token_hash: token_hash, is_revoked: is_revoked}} =
      Guardian.decode_and_verify(Ret.Api.Token, token)

    assert expected_hash == token_hash
    assert is_revoked == false

    Ret.Api.Token.revoke(token)

    {:ok, %Credentials{is_revoked: is_revoked_2}} = Guardian.decode_and_verify(Ret.Api.Token, token)
    assert is_revoked_2 == true
  end

  test "Api tokens can be associated with an account" do
    account = Ret.Account.find_or_create_account_for_email("test@mozilla.com")
    {:ok, token, _claims} = TokenUtils.gen_token_for_account(account)
    {:ok, credentials, _claims} = Guardian.resource_from_token(Ret.Api.Token, token)
    assert credentials.account_id === account.account_id
  end
end
