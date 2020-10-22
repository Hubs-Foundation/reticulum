defmodule Ret.Api.TokenUtils do
  @moduledoc """
  Utility functions for generating API access tokens.
  """
  @default_claims %{aud: "ret", iss: "ret", typ: "access", scopes: []}
  # TODO: When should tokens expire?
  @default_options [ttl: {8, :weeks}]

  alias Ret.Account
  alias Ret.Api.{Token, Scopes}

  def gen_app_token(scopes \\ [Scopes.read_rooms(), Scopes.write_rooms(), Scopes.create_accounts()]) do
    Token.encode_and_sign(
      :reticulum_app_token,
      Map.put(@default_claims, :scopes, scopes),
      @default_options
    )
  end

  def gen_token_for_account(%Account{} = account, scopes \\ [Scopes.read_rooms(), Scopes.write_rooms()]) do
    Token.encode_and_sign(
      account,
      Map.put(@default_claims, :scopes, scopes),
      @default_options
    )
  end
end
