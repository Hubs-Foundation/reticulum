defmodule RetWeb.HealthController do
  use RetWeb, :controller
  import Ecto.Query
  require Logger

  def index(conn, _params) do
    try do
      # Check database
      if module_config(:check_repo) do
        Ret.Repo.all(from Ret.Hub, limit: 0)
      end

      # Check page cache
      true = Cachex.get(:page_chunks, {:hubs, "index.html"}) |> elem(1) |> Enum.count() > 0
      true = Cachex.get(:page_chunks, {:hubs, "hub.html"}) |> elem(1) |> Enum.count() > 0
      true = Cachex.get(:page_chunks, {:spoke, "index.html"}) |> elem(1) |> Enum.count() > 0

      # Check room routing
      true = Ret.RoomAssigner.get_available_host("") != nil

      send_resp(conn, 200, "ok")
    rescue
      error ->
        {filename, line, function} = extract_our_code_location(__STACKTRACE__)

        Logger.error(
          "Health check failed at #{filename}:#{line} calling #{function}: #{inspect(error)}"
        )

        send_resp(conn, 500, "error")
    end
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
