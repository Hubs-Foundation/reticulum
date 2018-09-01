defmodule Ret.LoginTokenTest do
  use Ret.DataCase

  alias Ret.LoginToken

  test "should generate valid changeset for email" do
    changeset = LoginToken.changeset_for_email(%LoginToken{}, "test@mozilla.com")
    assert changeset.valid?
  end

  test "should generate a valid token" do
    token = LoginToken.new_token_for_email("test@mozilla.com")
    assert LoginToken.identifier_hash_for_token(token) == Ret.Crypto.hash("test@mozilla.com")
  end

  test "should allow expiring a token" do
    token = LoginToken.new_token_for_email("test@mozilla.com")
    LoginToken.expire!(token)
    assert LoginToken.identifier_hash_for_token(token) == nil
  end
end
