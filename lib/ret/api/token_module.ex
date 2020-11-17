defmodule Ret.Api.TokenModule do
  @moduledoc """
  This module should not be used directly.

  It is intended to be used by Guardian.
  """
  alias Ret.{Account, Repo}
  alias Ret.Api.Credentials
  @behaviour Guardian.Token

  @doc """
  No concept of validating signature so we just decode the token
  """
  def peek(mod, token) do
    case decode_token(mod, token) do
      {:ok, %Credentials{} = credentials} -> %{claims: credentials}
      {:ok, {:error, _reason}} -> nil
      _ -> nil
    end
  end

  @doc """
  Do not need to generate a token_id here
  """
  def token_id, do: nil

  @doc """
  Builds the default claims for API tokens.
  """
  def build_claims(_mod, _resource, _sub, claims \\ %{}, _options \\ []) do
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
    account_id = Map.get(claims, "account_id", nil)

    case get_account(account_id) do
      {:ok, account_or_nil} ->
        case Ret.Api.Credentials.generate_credentials(%{
               subject_type: ensure_atom(Map.get(claims, "subject_type")),
               scopes: Map.get(claims, "scopes"),
               account_or_nil: account_or_nil
             }) do
          {:ok, token, _credentials} -> {:ok, token}
          _ -> {:error, "Failed to create token for claims."}
        end

      {:error, _reason} ->
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
      # Don't want to return the error at this level,
      # so we pass it along for graphql to handle
      nil -> {:ok, {:error, :invalid_token}}
      credentials -> {:ok, credentials}
    end
  end

  @doc """
  Verifies the claims.
  """
  def verify_claims(_mod, claims, _options) do
    {:ok, claims}
  end

  @doc """
  Revoke a token
  """
  def revoke(_mod, %Credentials{} = credentials, _token, _options) do
    Ret.Api.Credentials.revoke(credentials)
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
