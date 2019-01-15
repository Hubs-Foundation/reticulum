defmodule Ret.PermsToken do
  use Guardian, otp_app: :ret

  alias Ret.{Account, Repo}

  def subject_for_token(_resource, %{"account_id" => account_id, "hub_id" => hub_id}) do
    {:ok, "#{account_id |> to_string}_#{hub_id}"}
  end

  def subject_for_token(_, _) do
    {:error, "Not found"}
  end
end
