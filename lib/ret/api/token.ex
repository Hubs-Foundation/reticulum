defmodule Ret.Api.Token do
  @moduledoc """
  ApiTokens determine what actions are allowed to be taken via the public API.
  """
  use Guardian, token_module: Ret.Api.TokenModule, otp_app: :ret

  alias Ret.Api.Credentials

  def subject_for_token(_, _), do: {:ok, nil}

  def resource_from_claims(%Credentials{} = credentials) do
    {:ok, credentials}
  end

  def resource_from_claims(_) do
    {:error, :invalid_token}
  end
end
