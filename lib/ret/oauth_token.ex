defmodule Ret.OAuthToken do
  use Guardian, otp_app: :ret

  def subject_for_token(_, _), do: {:ok, nil}

  def resource_from_claims(_), do: nil

  def token_for_hub(hub_sid) do
    secret = module_config(:oauth_token_key) |> JOSE.JWK.from_oct()

    {:ok, token, _claims} =
      Ret.OAuthToken.encode_and_sign(
        # OAuthTokens do not have a resource associated with them
        nil,
        %{hub_sid: hub_sid, aud: :ret_oauth},
        secret: secret,
        allowed_algos: ["HS512"],
        ttl: {5, :minutes},
        allowed_drift: 60 * 1000
      )

    token
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
