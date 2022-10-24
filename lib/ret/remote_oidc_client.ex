defmodule Ret.RemoteOIDCClient do
  @moduledoc """
  This represents an OpenID client configured via the openid_configuration parameter,
  which should point to a discovery endpoint https://openid.net/specs/openid-connect-discovery-1_0.html
  Downloaded configuration files openid-configuration and jwks_uri are cached indefinately.
  """

  require Logger

  def get_openid_configuration_uri() do
    Application.get_env(:ret, __MODULE__)[:openid_configuration]
  end

  defp download_openid_configuration() do
    Logger.info("Downloading OIDC configuration from #{get_openid_configuration_uri()}")
    result = get_openid_configuration_uri()
      |> Ret.HttpUtils.retry_get_until_success
      |> Map.get(:body)
      |> Poison.decode!()
    :persistent_term.put(:openid_configuration_cache, result)
    Logger.info("Downloaded OIDC configuration: #{inspect(result)}")
    result
  end

  defp get_openid_configuration() do
    :persistent_term.get(:openid_configuration_cache, nil) || download_openid_configuration()
  end

  defp get_jwks_uri() do
    get_openid_configuration() |> Map.get("jwks_uri")
  end

  defp download_jwks() do
    Logger.info("Downloading JWKS from #{get_jwks_uri()}")
    result = get_jwks_uri()
      |> Ret.HttpUtils.retry_get_until_success
      |> Map.get(:body)
      |> Poison.decode!()
    result |> IO.inspect
    :persistent_term.put(:openid_jwks_cache, result)
    Logger.info("Downloaded JWKS: #{inspect(result)}")
    result
  end

  def get_jwks() do
    :persistent_term.get(:openid_jwks_cache, nil) || download_jwks()
  end

  def get_auth_endpoint() do
    get_openid_configuration() |> Map.get("authorization_endpoint")
  end

  def get_token_endpoint() do
    get_openid_configuration() |> Map.get("token_endpoint")
  end

  def get_allowed_algos() do
    get_openid_configuration() |> Map.get("id_token_signing_alg_values_supported")
  end

  def get_userinfo_endpoint() do
    # Optional in spec
    get_openid_configuration() |> Map.get("userinfo_endpoint")
  end

  def get_scopes_supported() do
    # Optional in spec
    get_openid_configuration() |> Map.get("scopes_supported")
  end

  def get_scopes() do
    Application.get_env(:ret, __MODULE__)[:scopes]
  end

  def get_permitted_claims() do
    Application.get_env(:ret, __MODULE__)[:permitted_claims]
  end

  def get_client_id() do
    Application.get_env(:ret, __MODULE__)[:client_id]
  end

  def get_client_secret() do
    Application.get_env(:ret, __MODULE__)[:client_secret]
  end

end
