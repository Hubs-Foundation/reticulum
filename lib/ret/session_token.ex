defmodule Ret.SessionToken do
  use Guardian, otp_app: :ret, secret_fetcher: Ret.SessionTokenSecretFetcher, allowed_algos: ["HS512"]

  def subject_for_token(_resource, %{"session_id" => session_id}) do
    {:ok, "#{session_id}"}
  end

  def resource_from_claims(_), do: nil

  def token_for_session(session_id) do
    {:ok, token, _claims} =
      Ret.SessionToken.encode_and_sign(
        # SessionTokens do not have a resource associated with them
        nil,
        %{
          session_id: session_id,
          aud: :ret_session
        },
        ttl: {1, :days},
        allowed_drift: 60 * 1000
      )

    token
  end
end

defmodule Ret.SessionTokenSecretFetcher do
  def fetch_signing_secret(_mod, _opts) do
    {:ok, Application.get_env(:ret, Ret.Guardian)[:secret_key] |> JOSE.JWK.from_oct()}
  end

  def fetch_verifying_secret(_mod, _token_headers, _opts) do
    {:ok, Application.get_env(:ret, Ret.Guardian)[:secret_key] |> JOSE.JWK.from_oct()}
  end
end
