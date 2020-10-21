defmodule Ret.ApiTokenTest do
  use Ret.DataCase

  alias Ret.Api.TokenUtils

  defp token_query do
    from("guardian_tokens", select: [:jti, :aud, :jwt, :claims])
  end

  test "Generating an api token puts it in the database" do
    {:ok, token, _claims} = TokenUtils.gen_app_token()
    [%{jwt: jwt}] = Repo.all(token_query())
    assert jwt == token
  end

  test "Api tokens can be revoked" do
    {:ok, token, _claims} = TokenUtils.gen_app_token()
    [%{jwt: jwt}] = Repo.all(token_query())
    assert jwt == token
    {:ok, _claims} = Guardian.decode_and_verify(Ret.Api.Token, token)

    Guardian.revoke(Ret.Api.Token, token)
    assert Enum.empty?(Repo.all(token_query()))

    {:error, :token_not_found} = Guardian.decode_and_verify(Ret.Api.Token, token)
  end

  test "Api tokens can be associated with an account" do
    account = Ret.Account.find_or_create_account_for_email("test@mozilla.com")
    {:ok, token, _claims} = TokenUtils.gen_token_for_account(account)
    {:ok, resource, _claims} = Guardian.resource_from_token(Ret.Api.Token, token)
    assert resource.account_id === account.account_id
  end

  test "Revoked tokens cannot recover accounts" do
    account = Ret.Account.find_or_create_account_for_email("test@mozilla.com")
    {:ok, token, _claims} = TokenUtils.gen_token_for_account(account)
    Guardian.revoke(Ret.Api.Token, token)
    {:error, :token_not_found} = Guardian.resource_from_token(Ret.Api.Token, token)
  end
end
