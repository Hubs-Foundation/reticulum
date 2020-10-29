defmodule Ret.RemoteOIDCToken do
  @moduledoc """
  This represents an OpenID Connect token returned from a remote service.
  The public keys will be configured by an admin for a particular setup.
  """
  use Guardian,
    otp_app: :ret,
    secret_fetcher: Ret.RemoteOIDCTokenSecretsFetcher

  def subject_for_token(_, _), do: {:ok, nil}
  def resource_from_claims(_), do: {:ok, nil}
end

defmodule Ret.RemoteOIDCTokenSecretsFetcher do
  def fetch_signing_secret(_mod, _opts) do
    {:error, :not_implemented}
  end

  def fetch_verifying_secret(mod, token_headers, _opts) do
    IO.inspect(token_headers)

    # TODO use KID to look up the key. Do we want to bake it into the config at setup time? Fetch and cache? Should it be optional?
    {:ok, Application.get_env(:ret, mod)[:verification_key] |> JOSE.JWK.from_pem()} |> IO.inspect()
  end
end
