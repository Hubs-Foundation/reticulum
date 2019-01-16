defmodule Ret.PermsToken do
  use Guardian, otp_app: :ret

  def subject_for_token(_resource, %{"account_id" => account_id, "hub_id" => hub_id}) do
    {:ok, "#{account_id |> to_string}_#{hub_id}"}
  end

  def subject_for_token(_, _) do
    {:error, "Not found"}
  end

  def resource_from_claims(_), do: nil

  def token_for_perms(perms) do
    secret = module_config(:perms_key) |> JOSE.JWK.from_pem()
    Ret.PermsToken.encode_and_sign(nil, perms, secret: secret, allowed_algos: ["RS512"])
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
