defmodule RetWeb.RoomChannel do
  use RetWeb, :channel

  alias RetWeb.Presence

  def join("room:" <> _room_id, _payload, socket) do
    send self(), :after_join
    {:ok, socket}
  end

  def handle_in("message:new", message, socket) do
    broadcast! socket, "message:new", %{
      sender: socket.assigns.username,
      body: message["body"],
      timestamp: :os.system_time(:seconds)
    }
    {:noreply, socket}
  end

  def handle_info(:after_join, socket) do
    Presence.track(socket, socket.assigns.username, %{
      online_at: :os.system_time(:seconds)
    })
    push socket, "presence_state", Presence.list(socket)
    {:noreply, socket}
  end
end
