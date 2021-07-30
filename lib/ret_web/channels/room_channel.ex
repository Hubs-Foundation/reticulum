defmodule RetWeb.RoomChannel do
  use RetWeb, :channel

  alias RetWeb.{Presence}

  def join("room:" <> room_sid, _params, socket) do
    send(self(), {:begin_tracking, socket.assigns.session_id, %{foo: "bar", session_id: socket.assigns.session_id}})
    {:ok, nil, socket}
  end

  def handle_info({:begin_tracking, session_id, payload}, socket) do
    {:ok, _ } = Presence.track(socket, session_id, payload)
    push(socket, "presence_state", socket |> Presence.list())
    {:noreply, socket}
  end

  def handle_in(event, payload, socket) do
    broadcast_from!(socket, event, payload)
    {:noreply, socket}
  end

end
