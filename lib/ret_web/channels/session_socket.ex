defmodule RetWeb.SessionSocket do
  use Phoenix.Socket

  transport(:websocket, Phoenix.Transports.WebSocket, check_origin: false)

  channel("ret", RetWeb.RetChannel)
  channel("hub:*", RetWeb.HubChannel)
  channel("link:*", RetWeb.LinkChannel)
  channel("auth:*", RetWeb.AuthChannel)

  def id(socket) do
    "session:#{socket.assigns.session_id}"
  end

  def connect(%{}, socket) do
    socket =
      socket
      |> assign(:session_id, SecureRandom.uuid())
      |> assign(:started_at, NaiveDateTime.utc_now())

    {:ok, socket}
  end
end
