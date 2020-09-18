defmodule Ret.ApiPermissions do
  @moduledoc """
  A collection of permissions that can be bestowed on an ApiToken
  """

  use Bitwise

  @none 0x0000_0000
  @all 0xFFFF_FFFF
  @permissions %{
    (1 <<< 0) => :rooms_mutation_create_room,
    (1 <<< 1) => :rooms_mutation_update_room,
    (1 <<< 2) => :rooms_query_created_rooms,
    (1 <<< 3) => :rooms_query_favorite_rooms,
    (1 <<< 4) => :rooms_query_public_rooms,
    (1 <<< 5) => :unused,
    (1 <<< 6) => :unused,
    (1 <<< 7) => :unused,
    (1 <<< 8) => :unused,
    (1 <<< 9) => :unused,
    (1 <<< 10) => :unused,
    (1 <<< 11) => :unused,
    (1 <<< 12) => :unused,
    (1 <<< 13) => :unused,
    (1 <<< 14) => :unused,
    (1 <<< 15) => :unused,
    (1 <<< 16) => :unused,
    (1 <<< 17) => :unused,
    (1 <<< 18) => :unused,
    (1 <<< 19) => :unused,
    (1 <<< 20) => :unused,
    (1 <<< 21) => :unused,
    (1 <<< 22) => :unused,
    (1 <<< 23) => :unused,
    (1 <<< 24) => :unused,
    (1 <<< 25) => :unused,
    (1 <<< 26) => :unused,
    (1 <<< 27) => :unused,
    (1 <<< 28) => :unused,
    (1 <<< 29) => :unused,
    (1 <<< 30) => :unused,
    (1 <<< 31) => :unused
  }

  defp permissions_to_map(bit_field) do
    bit_field |> BitFieldUtils.permissions_to_map(@permissions)
  end
end

defmodule Ret.ApiToken do
  @moduledoc """
  ApiTokens determine what actions are allowed to be taken via the public API.
  """
  use Guardian, otp_app: :ret, secret_fetcher: Ret.ApiTokenSecretFetcher

  def subject_for_token(_, _), do: {:ok, nil}

  def resource_from_claims(_), do: nil

  # TODO: Where to add permissions?
  # TODO: Where to set token_type to "api" (insert "typ" => "api" into claims map)

  # guadian hooks for guardian_db
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
end

defmodule Ret.ApiTokenSecretFetcher do
  @moduledoc false
  def fetch_signing_secret(_mod, _opts) do
    {:ok, Application.get_env(:ret, Ret.ApiToken)[:secret_key] |> JOSE.JWK.from_oct()}
  end

  def fetch_verifying_secret(_mod, _token_headers, _opts) do
    {:ok, Application.get_env(:ret, Ret.ApiToken)[:secret_key] |> JOSE.JWK.from_oct()}
  end

  #TODO: How to set configuration for prod?
end
