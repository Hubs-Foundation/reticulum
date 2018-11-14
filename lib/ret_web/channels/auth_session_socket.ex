defmodule RetWeb.AuthSessionSocket do
  use Phoenix.Socket

  transport(:websocket, Phoenix.Transports.WebSocket, check_origin: false)

  channel("ret", RetWeb.RetChannel)
  channel("hub:*", RetWeb.HubChannel)
  channel("link:*", RetWeb.LinkChannel)
  channel("auth:*", RetWeb.AuthChannel)

  def id(socket) do
    "session:#{socket.assigns.session_id}"
  end

  def connect(%{"token" => token, "session_id" => session_id}, socket) do
    socket = socket |> assign_session(session_id)

    case Guardian.Phoenix.Socket.authenticate(socket, Ret.Guardian, token) do
      {:ok, socket} -> {:ok, socket}
      {:error, _} -> :error
    end
  end

  def connect(%{"session_id" => session_id}, socket) do
    {:ok, socket |> assign_session(session_id)}
  end

  defp assign_session(socket, session_id) do
    socket
    |> assign(:session_id, session_id)
    |> assign(:started_at, NaiveDateTime.utc_now())
  end
end
