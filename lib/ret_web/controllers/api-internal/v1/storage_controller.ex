defmodule RetWeb.ApiInternal.V1.StorageController do
  use RetWeb, :controller

  def show(conn, _) do
    {:ok, storage_used_kb} = Ret.Storage.storage_used()

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, %{storage_mb: storage_used_kb / 1024} |> Poison.encode!())
  end
end
