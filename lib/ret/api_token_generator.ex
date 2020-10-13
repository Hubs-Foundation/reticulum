# TODO: Remove this file
defmodule Ret.ApiTokenGenerator do
  @moduledoc """
  Generate API tokens with appropriate scope
  """
  alias Ret.{Account, ApiToken, ApiPermissions}

  def gen_token() do
    ApiToken.gen_app_token()
  end

  def gen_token_for_account(%Account{} = account) do
    ApiToken.gen_token_for_account(account)
  end

  def gen_token_for_account(_account) do
    {:error, "Did not specify account."}
  end
end
