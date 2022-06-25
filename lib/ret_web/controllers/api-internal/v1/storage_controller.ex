defmodule RetWeb.ApiInternal.V1.StorageController do
  use RetWeb, :controller
  alias Ret.StorageUsed

  def show(conn, _) do
    conn = put_resp_header(conn, "content-type", "application/json")

    case Ret.Storage.storage_used() do
      {:ok, storage_used} when is_number(storage_used) ->
        storage_used_mb =
          if System.get_env("TURKEY_MODE") do
            StorageUsed.convert_du_units_into_mb(storage_used)
          else
            storage_used / 1024
          end

        send_resp(conn, 200, %{storage_mb: storage_used_mb} |> Poison.encode!())

      _ ->
        send_resp(conn, 503, %{error: :storage_usage_unavailable} |> Poison.encode!())
    end
  end
end
