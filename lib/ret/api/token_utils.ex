defmodule Ret.Api.TokenUtils do
  @moduledoc """
  Utility functions for generating API access tokens.
  """
  alias Ret.{Account, Repo}
  alias Ret.Api.{Credentials, Token, Scopes}

  import Canada, only: [can?: 2]

  def gen_app_token(scopes \\ [Scopes.read_rooms(), Scopes.write_rooms()]) do
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
    }                       )
  end

  defp ensure_atom(x) when is_atom(x), do: x
  defp ensure_atom(x) when is_binary(x), do: String.to_atom(x)

  defp account_id_from_args(%Account{}, %{"account_id" => account_id}) do
    # This account wants to create credentials on behalf of another account
    account_id
  end

  defp account_id_from_args(%Account{} = account, _params) do
    # This account wants to create credentials for itself
    account.account_id
  end

  defp validate_account_id(%Account{account_id: account_id}, account_id) do
    # Skip a trip to the DB if account is creating credentials for itself
    []
  end

  defp validate_account_id(%Account{}, account_id) do
    # Make sure the given account_id refers to an account that actually exists
    validate_field(:account_id, account_id)
  end

  defp validate_field(:account_id, account_id) do
    if Account.query()
       |> Account.where_account_id_is(account_id)
       |> Repo.exists?() do
      []
    else
      [account_id: "Invalid account id #{account_id}"]
    end
  end

  def to_claims(%Account{} = account, %{"subject_type" => subject_type, "scopes" => scopes} = params) do
    account_id_for_claims = account_id_from_args(account, params)

    case validate_account_id(account, account_id_for_claims) ++
           Credentials.validate_field(:scopes, scopes) ++
           Credentials.validate_field(:subject_type, subject_type) do
      [] ->
        # It is safe to cast user-provided strings to atoms here
        # because we validated that the strings match our atoms
        # (with &valid_value?/1 from ecto_enum)
        {:ok,
         %{
           account_id: account_id_for_claims,
           subject_type: ensure_atom(subject_type),
           scopes: Enum.map(scopes, &ensure_atom/1)
         }}

      error_list ->
        {:error, error_list}
    end
  end

  def authed_create_credentials(account, claims) do
    if can?(account, create_credentials(claims)) do
      Token.encode_and_sign(nil, claims)
    else
      {:error, :unauthorized}
    end
  end

  def authed_list_credentials(account, subject_type) do
    if can?(account, list_credentials(subject_type)) do
      list_credentials(account, subject_type)
    else
      {:error, :unauthorized}
    end
  end

  defp list_credentials(account, :account) do
    Credentials.query()
    |> Credentials.where_account_is(account)
    |> Credentials.where_token_is_not_revoked()
    |> Repo.all()
  end

  defp list_credentials(_account, :app) do
    Credentials.app_token_query()
    |> Repo.all()
  end

  def authed_revoke_credentials(account, credentials) do
    if can?(account, revoke_credentials(credentials)) do
      Credentials.revoke(credentials)
    else
      {:error, :unauthorized}
    end
  end
end
