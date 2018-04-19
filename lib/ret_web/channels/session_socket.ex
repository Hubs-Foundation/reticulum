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
        "http://hubs.dev:4000",
        "https://hubs.dev:8080"
      ]
    )
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
