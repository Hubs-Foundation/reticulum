defmodule RetWeb.SessionSocket do
  use Phoenix.Socket

  # If origin * was specified, disable origin check for websockets
  if Enum.member?(Application.get_env(:cors_plug, :origin) || [], "*") do
    transport(:websocket, Phoenix.Transports.WebSocket, check_origin: false)
  else
    transport(:websocket, Phoenix.Transports.WebSocket)
  end

  channel("hub:*", RetWeb.HubChannel)

  def id(socket) do
    "session:#{socket.assigns.session_id}"
  end

  def connect(%{"session_id" => session_id}, socket) do
    socket =
      socket
      |> assign(:session_id, session_id)
      |> assign(:started_at, NaiveDateTime.utc_now())

    {:ok, socket}
  end
end
