defmodule RetWeb.LinkChannel do
  @moduledoc "Ret Web Channel for Device links"

  use RetWeb, :channel

  alias Ret.{Statix}
  alias RetWeb.{Presence}

  intercept ["link_response"]

  def join("link:" <> link_code, _payload, socket) do
    if Regex.match?(~r/\A[0-9A-Z]{4,6}\z/, link_code) do
      # Expire channel in 5 minutes
      Process.send_after(self(), :channel_expired, 60 * 1000 * 5)

      # Rate limit joins to reduce attack surface
      :timer.sleep(500)

      send(self(), {:begin_tracking, socket.assigns.session_id, link_code})

      Statix.increment("ret.channels.link.joins.ok")
      {:ok, %{session_id: socket.assigns.session_id}, socket}
    else
      {:error, %{event: "Invalid link code"}}
    end
  end

  def handle_in("link_request" = event, payload, socket) do
    broadcast!(socket, event, payload)

    {:noreply, socket}
  end

  def handle_in("link_response" = event, payload, socket) do
    broadcast!(socket, event, payload)

    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  def handle_out(
        "link_response" = event,
        %{"target_session_id" => target_session_id} = payload,
        socket
      ) do
    if target_session_id == socket.assigns.session_id do
      push(socket, event, payload)
    end

    {:noreply, socket}
  end

  def handle_info({:begin_tracking, session_id, link_code}, socket) do
    push(socket, "presence_state", Presence.list(socket))
    {:ok, _} = Presence.track(socket, session_id, %{link_code: link_code})
    {:noreply, socket}
  end

  def handle_info(:channel_expired, socket) do
    push(socket, "link_expired", %{})
    GenServer.cast(self(), :close)
    {:noreply, socket}
  end
end
