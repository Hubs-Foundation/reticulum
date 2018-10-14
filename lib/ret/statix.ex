defmodule Ret.Statix do
  use Statix
  @memory_stats ~w(atom binary ets processes system processes_used atom_used ets total)a

  def send_gauges do
    for stat <- @memory_stats, do: gauge("erl.memory.#{stat}", :erlang.memory(stat))
    gauge("ret.present_sessions", RetWeb.Presence.present_session_count())
    gauge("ret.present_rooms", RetWeb.Presence.present_room_count())
    gauge("ret.nodes", (Node.list() |> Enum.count()) + 1)
  end
end
