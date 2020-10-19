defmodule Ret.Api.Credentials do
  @moduledoc """
  Credentials for API access. Created by decoding/validating ApiTokens
  """

  alias Ret.Account
  alias Ret.Api.Scopes

  @enforce_keys [:resource, :scopes]
  defstruct [:resource, :scopes]

  def from_resource_and_claims(:reticulum_app_token, %{"scopes" => scopes}) do
    with credentials <- %__MODULE__{resource: :reticulum_app_token, scopes: scopes} do
      {:ok, credentials}
    end
  end

  def from_resource_and_claims(%Account{} = resource, %{"scopes" => scopes}) do
    with credentials <- %__MODULE__{resource: resource, scopes: scopes} do
      {:ok, credentials}
    end
  end

  def from_resource_and_claims(_, _) do
    {:error, "Invalid credentials"}
  end
end
