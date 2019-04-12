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

  def connect(%{"session_token" => session_token}, socket) do
    session_id =
      case session_token |> Ret.SessionToken.decode_and_verify() do
        {:ok, %{"session_id" => session_id}} -> session_id
        _ -> nil
      end

    socket =
      socket
      |> assign(:session_id, session_id || SecureRandom.uuid())
      |> assign(:started_at, NaiveDateTime.utc_now())

    {:ok, socket}
  end

  def connect(%{}, socket) do
    socket =
      socket
      |> assign(:session_id, SecureRandom.uuid())
      |> assign(:started_at, NaiveDateTime.utc_now())

    {:ok, socket}
  end
end
