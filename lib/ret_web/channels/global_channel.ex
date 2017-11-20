defmodule RetWeb.GlobalChannel do
  use RetWeb, :channel

  alias RetWeb.Presence

  intercept ["message:new"]

  def join("global:" <> _, _payload, socket) do
      send self(), :after_join
      {:ok, socket}
  end

  def handle_in("message:new", payload, socket) do
    if (payload["sender"] == socket.assigns.username && 
        payload["sender"] != payload["receiver"]) do
      broadcast! socket, "message:new", %{
        receiver: payload["receiver"],
        sender: payload["sender"],
        body: payload["body"],
        timestamp: :os.system_time(:seconds)
      }
    end
    {:noreply, socket}
  end

  def handle_out("message:new", payload, socket) do
    if (payload.receiver == socket.assigns.username) do
      push socket, "message:new", payload
    end
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
