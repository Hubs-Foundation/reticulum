defmodule RetWeb.Presence do
  use Phoenix.Presence,
    otp_app: :ret,
    pubsub_server: Ret.PubSub

  alias Phoenix.Tracker.{State}

  def present_session_count do
    present_sessions() |> Enum.map(& &1[:session_id]) |> Enum.uniq() |> length
  end

  def present_room_count do
    present_sessions() |> Enum.map(& &1[:hub_sid]) |> Enum.uniq() |> length
  end

  defp present_sessions do
    __MODULE__
    |> GenServer.call({:list, nil})
    |> State.online_list()
    |> Enum.map(fn {{_topic, _pid, session_id}, %{hub_id: hub_id}, _tag} ->
      %{session_id: session_id, hub_id: hub_id}
    end)
  end
end
