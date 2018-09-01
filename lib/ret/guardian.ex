defmodule Ret.Guardian do
  use Guardian, otp_app: :ret
  alias Ret.{Account, Repo}

  def subject_for_token(%Account{} = account, _claims) do
    {:ok, account.account_id |> to_string}
  end

  def subject_for_token(_, _) do
    {:error, "Not found"}
  end

  def resource_from_claims(%{"sub" => account_id}) do
    {:ok, Account |> Repo.get(account_id)}
  end

  def resource_from_claims(_claims) do
    {:error, "No subject"}
  end
end
