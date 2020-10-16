defmodule Ret.Api.Token do
  @moduledoc """
  ApiTokens determine what actions are allowed to be taken via the public API.
  """
  use Guardian, otp_app: :ret, secret_fetcher: Ret.ApiTokenSecretFetcher

  import Ecto.Query

  alias Ret.{Account, Repo, ApiToken}
  alias Ret.Api.Scopes

  @app_token_string "reticulum_app_token"
  @app_token_atom :reticulum_app_token

  def subject_for_token(%Account{} = account, _), do: {:ok, to_string(account.account_id)}
  def subject_for_token(@app_token_atom, _), do: {:ok, @app_token_string}
  def subject_for_token(_, _), do: {:error, "Must pass account or #{@app_token_string}"}

  def resource_from_claims(%{"sub" => nil}) do
    {:error, "No subject in token"}
  end

  def resource_from_claims(%{"sub" => @app_token_string}) do
    {:ok, @app_token_atom}
  end

  def resource_from_claims(%{"sub" => account_id}) do
    result_for_account(Repo.one(where(Account, [a], a.account_id == ^account_id)))
  end

  defp result_for_account(%Account{} = account), do: {:ok, account}
  defp result_for_account(nil), do: {:error, "Account not found"}

  def after_encode_and_sign(resource, claims, token, _options) do
    with {:ok, _} <- Guardian.DB.after_encode_and_sign(resource, claims["typ"], claims, token) do
      {:ok, token}
    end
  end

  def on_verify(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_verify(claims, token) do
      {:ok, claims}
    end
  end

  def on_refresh({old_token, old_claims}, {new_token, new_claims}, _options) do
    with {:ok, _, _} <- Guardian.DB.on_refresh({old_token, old_claims}, {new_token, new_claims}) do
      {:ok, {old_token, old_claims}, {new_token, new_claims}}
    end
  end

  def on_revoke(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_revoke(claims, token) do
      {:ok, claims}
    end
  end

  @default_claims %{aud: "ret", iss: "ret", typ: "access", scopes: []}
  @default_options [ttl: {8, :hours}]

  def gen_app_token(scopes \\ [Scopes.read_rooms(), Scopes.write_rooms(), Scopes.create_accounts()]) do
    ApiToken.encode_and_sign(
      @app_token_atom,
      Map.put(@default_claims, :scopes, scopes),
      @default_options
    )
  end

  def gen_token_for_account(%Account{} = account, scopes \\ [Scopes.read_rooms(), Scopes.write_rooms()]) do
    ApiToken.encode_and_sign(
      account,
      Map.put(@default_claims, :scopes, scopes),
      @default_options
    )
  end
end
