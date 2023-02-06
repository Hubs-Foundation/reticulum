defmodule RetWeb.ApiInternal.V1.PresenceController do
  use RetWeb, :controller
  alias Ret.NodeStat

  # Get presence count
  def show(conn, _) do
    count = RetWeb.Presence.present_ccu_in_room_count()

    conn |> send_resp(200, %{count: count} |> Poison.encode!())
  end

  # Params start_time and end_time should be in iso format such as "2000-02-28 23:00:13"
  # or what is returned from NaiveDateTime.to_string()
  def range_max(conn, %{"start_time" => start_time_str, "end_time" => end_time_str}) do
    max =
      NodeStat.max_ccu_for_time_range(
        start_time_str |> NaiveDateTime.from_iso8601!(),
        end_time_str |> NaiveDateTime.from_iso8601!()
      )

    conn |> send_resp(200, %{max_ccu: max} |> Poison.encode!())
  end
end
