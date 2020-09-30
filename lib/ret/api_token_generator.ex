defmodule Ret.ApiTokenGenerator do
  @moduledoc """
  Generate API tokens with appropriate scope
  """
  alias Ret.{Account, ApiToken, ApiPermissions}

  defp default_claims() do
    %{aud: "ret", typ: "api"}
  end

  defp default_options() do
    # TODO: This should be taken from env -- not overwritten here
    [ttl: {8, :hours}]
  end

  def gen_token() do
    ApiToken.encode_and_sign(
      nil,
      Map.merge(ApiPermissions.default_permissions(), default_claims()),
      default_options()
    )
  end

  def gen_token_for_account(%Account{} = account) do
    ApiToken.encode_and_sign(
      account,
      Map.merge(ApiPermissions.perms_for_account(), default_claims()),
      default_options()
    )
  end

  def gen_token_for_account(_account) do
    {:error, "Did not specify account."}
  end
end
