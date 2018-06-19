defmodule RetWeb.SessionSocket do
  use Phoenix.Socket

  # If origin * was specified, disable origin check for websockets
  if Mix.env() == :dev do
    transport(:websocket, Phoenix.Transports.WebSocket)
  else
    transport(
      :websocket,
      Phoenix.Transports.WebSocket,
      check_origin: [
        "https://prod.reticulum.io",
        "https://smoke-prod.reticulum.io",
        "https://dev.reticulum.io",
        "https://smoke-dev.reticulum.io",
        "https://hubs.social",
        "https://hubs.mozilla.com",
        "https://smoke-hubs.mozilla.com",
        "https://localhost:8080",
        "https://hubs.local:8080"
      ]
    )
  end

  channel("hub:*", RetWeb.HubChannel)
  channel("link:*", RetWeb.LinkChannel)

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
