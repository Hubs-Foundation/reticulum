defmodule RetWeb.ApiInternal.V1.StorageController do
  use RetWeb, :controller

  def show(conn, _) do
    conn = put_resp_header(conn, "content-type", "application/json")

    case Ret.Storage.storage_used() do
      {:ok, storage_used_kb} when is_number(storage_used_kb) ->
        send_resp(conn, 200, %{storage_mb: storage_used_kb / 1024} |> Poison.encode!())

      _ ->
        send_resp(conn, 503, %{error: :storage_usage_unavailable} |> Poison.encode!())
    end
  end
end
