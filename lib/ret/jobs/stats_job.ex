defmodule Ret.StatsJob do
  alias Ret.{Repo, NodeStat}

  def send_statsd_gauges do
    if module_config(:node_gauges_enabled) do
      Ret.Statix.send_gauges()
    end
  end

  def save_node_stats do
    if module_config(:node_stats_enabled) do
      {:ok, _} =
        with node_id <- Node.self() |> to_string,
             measured_at <- NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
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

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
