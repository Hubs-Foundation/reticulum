defmodule RetWeb.Presence do
  use Phoenix.Presence,
    otp_app: :ret,
    pubsub_server: Ret.PubSub

  def present_session_count do
    present_sessions() |> Enum.count()
  end

  def present_hub_sids do
    present_sessions()
    |> Map.values()
    |> Enum.map(&(&1[:metas] |> Enum.at(0) |> Map.get(:hub_id)))
  end

  def present_room_count do
    present_hub_sids()
    |> Enum.uniq()
    |> length
  end

  def present_member_count do
    RetWeb.Presence.present_hub_sids()
    |> Enum.map(&Ret.Hub.member_count_for/1)
    |> Enum.sum()
  end

  # Get number of hub room connections: lobby, ghosts, and in-room avatars
  def present_ccu_in_room_count do
    RetWeb.Presence.present_hub_sids()
    |> Enum.filter(fn sid -> sid !== "admin" end)
    |> length
  end

  def has_present_members? do
    present_member_count() > 0
  end

  defp present_sessions do
    list("ret")
  end
end
