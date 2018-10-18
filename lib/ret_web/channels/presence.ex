defmodule RetWeb.Presence do
  use Phoenix.Presence,
    otp_app: :ret,
    pubsub_server: Ret.PubSub

  def present_session_count do
    present_sessions() |> Enum.count()
  end

  def present_room_count do
    present_sessions()
    |> Map.values()
    |> Enum.map(&(&1[:metas] |> Enum.at(0) |> Map.get(:hub_id)))
    |> Enum.uniq()
    |> length
  end

  defp present_sessions do
    list("ret")
  end
end
