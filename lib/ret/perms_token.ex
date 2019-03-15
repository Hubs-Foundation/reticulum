defmodule Ret.PermsToken do
  use Guardian, otp_app: :ret

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
    secret = module_config(:perms_key) |> JOSE.JWK.from_pem()

    {:ok, token, _claims} =
      Ret.PermsToken.encode_and_sign(
        # PermsTokens do not have a resource associated with them
        nil,
        perms |> Map.put(:aud, :ret_perms),
        secret: secret,
        allowed_algos: ["RS512"],
        ttl: {5, :minutes},
        allowed_drift: 60 * 1000
      )

    token
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
