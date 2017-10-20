defmodule RetWeb.ChatController do
  use RetWeb, :controller

  def index(conn, %{"room_id" => room_id}) do
    render conn, "index.html", room_id: room_id
  end
end
