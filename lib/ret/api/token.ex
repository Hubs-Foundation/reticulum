defmodule Ret.Api.Token do
  @moduledoc """
  ApiTokens determine what actions are allowed to be taken via the public API.
  """
  use Guardian, token_module: Ret.Api.TokenModule, otp_app: :ret, secret_fetcher: Ret.ApiTokenSecretFetcher

  import Ecto.Query

  alias Ret.{Account, Repo}
  alias Ret.Api.Credentials

  def subject_for_token(_, _), do: {:ok, nil}

  def resource_from_claims(%Credentials{} = credentials) do
    IO.inspect("creds:")
    IO.inspect(credentials)
    credentials
  end

  def resource_from_claims(claims) do
    IO.inspect("claims:")
    IO.inspect(claims)
    nil
  end
end
