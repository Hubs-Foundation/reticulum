defmodule Ret.StatsJob do
  alias Ret.{Repo, NodeStat}

  def send_statsd_gauges do
    Ret.Statix.send_gauges()
  end

  def save_node_stats do
    {:ok, _} =
      with node_id <- Node.self() |> to_string,
           measured_at <- NaiveDateTime.utc_now(),
           present_sessions <- RetWeb.Presence.present_session_count(),
           present_rooms <- RetWeb.Presence.present_room_count() do
        %NodeStat{}
        |> NodeStat.changeset(%{
          node_id: node_id,
          measured_at: measured_at,
          present_sessions: present_sessions,
          present_rooms: present_rooms
        })
        |> Repo.insert()
      end
  end
end
