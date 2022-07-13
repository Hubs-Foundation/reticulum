defmodule RetWeb.ApiInternal.V1.PresenceController do
  use RetWeb, :controller
  alias Ret.NodeStat

  # Get presence count
  def show(conn, _) do
    count = RetWeb.Presence.present_ccu_in_room_count()

    conn |> send_resp(200, %{count: count} |> Poison.encode!())
  end

  def daily_max(conn, %{start_time: start_time, end_time: end_time}) do
    max = NodeStat.max_ccu_for_timerange(start_time, end_time)
    conn |> send_resp(200, %{max_ccu: max} |> Poison.encode!())
  end
end
