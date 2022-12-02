defmodule Ret.PermsToken do
  @moduledoc """
  PermsTokens grant granular permissions to users in various contexts.
  They are signed with an RSA algorithm so that external systems can verify tokens with our corresponding public key.
  """
  use Guardian,
    otp_app: :ret,
    secret_fetcher: Ret.PermsTokenSecretFetcher,
    allowed_algos: ["RS512"]

  def subject_for_token(_resource, %{"account_id" => account_id, "hub_id" => hub_id}) do
    {:ok, "#{account_id}_#{hub_id}"}
  end

  def subject_for_token(_resource, %{"account_id" => account_id}) do
    {:ok, "#{account_id}_global"}
  end

  def subject_for_token(_, _) do
    {:ok, "anon"}
  end

  def resource_from_claims(_), do: nil

  def token_for_perms(perms) do
    {:ok, token, _claims} =
      Ret.PermsToken.encode_and_sign(
        # PermsTokens do not have a resource associated with them
        nil,
        perms |> Map.put(:aud, :ret_perms),
        ttl: {5, :minutes},
        allowed_drift: 60 * 1000
      )

    token
  end
end

defmodule Ret.PermsTokenSecretFetcher do
  def fetch_signing_secret(mod, _opts) do
    {:ok, Application.get_env(:ret, mod)[:perms_key] |> JOSE.JWK.from_pem()}
  end

  def fetch_verifying_secret(mod, _token_headers, _opts) do
    {:ok, Application.get_env(:ret, mod)[:perms_key] |> JOSE.JWK.from_pem()}
  end
end
