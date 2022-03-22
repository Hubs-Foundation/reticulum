defmodule RetWeb.Api.V1.PresenceController do
  use RetWeb, :controller

  # Get presence count
  def show(conn, _) do
    count = RetWeb.Presence.present_ccu_in_room_count()

    conn |> send_resp(200, %{count: count} |> Poison.encode!())
  end
end
