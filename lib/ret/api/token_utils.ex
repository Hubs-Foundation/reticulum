defmodule Ret.Api.TokenUtils do
  @moduledoc """
  Utility functions for generating API access tokens.
  """
  alias Ret.Account
  alias Ret.Api.{Token, Scopes}

  def gen_app_token(scopes \\ [Scopes.read_rooms(), Scopes.write_rooms(), Scopes.create_accounts()]) do
    Token.encode_and_sign(nil, %{
      subject_type: :app,
      scopes: scopes,
      account_id: nil
    })
  end

  def gen_token_for_account(%Account{} = account, scopes \\ [Scopes.read_rooms(), Scopes.write_rooms()]) do
    Token.encode_and_sign(nil, %{
      subject_type: :account,
      scopes: scopes,
      account_id: account.account_id
    })
  end
end