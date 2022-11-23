defmodule Ret.LoginTokenTest do
  use Ret.DataCase

  alias Ret.LoginToken

  test "should generate valid changeset for email" do
    changeset = LoginToken.changeset_for_email(%LoginToken{}, "test@mozilla.com")
    assert changeset.valid?
  end

  test "should generate a valid token" do
    %LoginToken{token: token} = LoginToken.new_login_token_for_email("test@mozilla.com")

    assert LoginToken.lookup_by_token(token).identifier_hash ==
             Ret.Crypto.hash("test@mozilla.com")
  end

  test "should allow expiring a token" do
    %LoginToken{token: token} = LoginToken.new_login_token_for_email("test@mozilla.com")
    LoginToken.expire(token)
    assert LoginToken.lookup_by_token(token) == nil
  end
end
