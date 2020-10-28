defmodule Ret.Api.TokenModule do
  @moduledoc """
  This module should not be used directly.

  It is intended to be used by Guardian.
  """
  alias Ret.{Account, Repo}
  alias Ret.Api.Credentials
  @behaviour Guardian.Token

  @doc """
  Cannot peek API Tokens
  """
  def peek(_mod, _token), do: nil

  @doc """
  Do not need to generate a token_id here
  """
  def token_id, do: nil

  @doc """
  Builds the default claims for API tokens.
  """
  def build_claims(mod, resource, sub, claims \\ %{}, options \\ []) do
    {:ok, claims}
  end

  defp ensure_atom(x) when is_atom(x), do: x
  defp ensure_atom(x) when is_binary(x), do: String.to_atom(x)

  defp get_account(id) when is_nil(id) do
    {:ok, nil}
  end

  defp get_account(id) do
    case Account.query()
         |> Account.where_account_id_is(id)
         |> Repo.one() do
      nil -> {:error, "Could not find account"}
      account -> {:ok, account}
    end
  end

  @doc """
  Create a token.
  """
  def create_token(_mod, claims, _options \\ []) do
    token = SecureRandom.urlsafe_base64()
    account_id = Map.get(claims, "account_id", nil)

    case get_account(account_id) do
      {:ok, account_or_nil} ->
        case Ret.Api.Credentials.create_new_api_credentials(%{
               subject_type: ensure_atom(Map.get(claims, "subject_type")),
               scopes: Map.get(claims, "scopes"),
               account: account_or_nil,
               token_hash: Ret.Crypto.hash(token)
             }) do
          {:ok, credentials} -> {:ok, token}
          _ -> {:error, "Failed to create token for claims."}
        end

      {:error, reason} ->
        {:error, "Failed to create token for claims."}
    end
  end

  @doc """
  Decodes the token and validates the signature.
  """
  def decode_token(_mod, token, _options \\ []) do
    case Credentials.query()
         |> Credentials.where_token_hash_is(Ret.Crypto.hash(token))
         |> Ret.Repo.one() do
      nil -> {:error, :credentials_not_found}
      credentials -> {:ok, credentials}
    end
  end

  @doc """
  Verifies the claims.
  """
  def verify_claims(mod, claims, options) do
    {:ok, claims}
  end

  @doc """
  Revoke a token
  """
  def revoke(_mod, %Credentials{} = claims, _token, _options) do
    Ret.Api.Credentials.revoke(claims)
  end

  @doc """
  Refresh the token
  """
  def refresh(_mod, _old_token, _options), do: nil

  @doc """
  Exchange a token of one type to another.
  """
  def exchange(_mod, _old_token, _from_type, _to_type, _options), do: nil
end
