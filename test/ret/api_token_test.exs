defmodule Ret.ApiTokenTest do
  use Ret.DataCase

  # alias Ecto.{Changeset}
  # alias Ret.{Account, Guardian, Repo}

  test "Creating a token puts it in the database" do
    {:ok, token, _claims} = Guardian.encode_and_sign(Ret.ApiToken, %{foo: :bar}, %{aud: "ret", typ: "api"})

    [%{jwt: jwt}] = Repo.all(from("guardian_tokens", select: [:jti, :aud, :jwt]))
    assert jwt == token
  end

  test "Tokens can be validated" do
    {:ok, token, claims} = Guardian.encode_and_sign(Ret.ApiToken, %{foo: :bar}, %{aud: "ret", typ: "api"})
    {:ok, decoded_claims} = Guardian.decode_and_verify(Ret.ApiToken, token)

    Enum.each(["aud", "exp", "iat", "iss", "jti", "nbf", "sub", "typ"], fn x ->
      assert Map.get(claims, x) === Map.get(decoded_claims, x)
    end)

    assert claims === decoded_claims
  end

  test "Tokens can be revoked" do
    {:ok, token, _claims} = Guardian.encode_and_sign(Ret.ApiToken, %{foo: :bar}, %{aud: "ret", typ: "api"})
    assert Enum.count(Repo.all(from("guardian_tokens", select: [:jti, :aud, :jwt]))) === 1
    Guardian.revoke(Ret.ApiToken, token)
    assert Enum.empty?(Repo.all(from("guardian_tokens", select: [:jti, :aud, :jwt])))
  end
end
