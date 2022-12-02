defmodule Ret.Guardian do
  @moduledoc """
  This is our primary, long-lived, authenticion token. We used to sign clients in and associate them with a Ret.Account.
  """
  use Guardian, otp_app: :ret
  import Ecto.Query

  alias Ret.{Account, Repo}

  def subject_for_token(%Account{} = account, _claims) do
    {:ok, account.account_id |> to_string}
  end

  def subject_for_token(_, _) do
    {:error, "Not found"}
  end

  def resource_from_claims(%{"sub" => account_id, "iat" => issued_at}) do
    issued_at_utc_datetime = DateTime.from_unix!(issued_at, :second) |> DateTime.to_iso8601()

    query =
      from a in Account,
        where: a.account_id == ^account_id,
        where: a.min_token_issued_at <= ^issued_at_utc_datetime,
        preload: [:oauth_providers, :identity]

    query
    |> Repo.one()
    |> result_for_account
  end

  def resource_from_claims(_claims) do
    {:error, "No subject"}
  end

  defp result_for_account(%Account{} = account), do: {:ok, account}
  defp result_for_account(nil), do: {:error, "Not found"}
end
