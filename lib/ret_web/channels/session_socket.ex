defmodule RetWeb.SessionSocket do
  use Phoenix.Socket

  transport :websocket, Phoenix.Transports.WebSocket
  channel "hub:*", RetWeb.HubChannel

  def id(socket) do
    IO.puts "ID: session:#{socket.assigns.session_id}"
    "session:#{socket.assigns.session_id}"
  end

  def connect(%{ "session_id" => session_id }, socket) do
    socket = socket |> assign(:session_id, session_id)
    { :ok, socket }
  end
end
