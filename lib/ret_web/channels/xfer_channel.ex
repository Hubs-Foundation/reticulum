defmodule RetWeb.XferChannel do
  @moduledoc "Ret Web Channel for Device XFers"

  use RetWeb, :channel

  alias Ret.{Statix}
  alias RetWeb.{Presence}

  intercept(["xfer_response"])

  def join("xfer:" <> xfer_code, _payload, socket) do
    if Regex.match?(~r/\A[0-9]{4,6}\z/, xfer_code) do
      # Expire channel in 5 minutes
      Process.send_after(self(), :channel_expired, 60 * 1000 * 5)

      # Rate limit joins to reduce attack surface
      :timer.sleep(2000)

      send(self(), {:begin_tracking, socket.assigns.session_id, xfer_code})

      Statix.increment("ret.channels.xfer.joins.ok")
      {:ok, "{}", socket}
    else
      {:error, %{event: "Invalid xfer code"}}
    end
  end

  def handle_in("xfer_request" = event, payload, socket) do
    broadcast!(socket, event, payload)

    {:noreply, socket}
  end

  def handle_in("xfer_response" = event, payload, socket) do
    broadcast!(socket, event, payload)

    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  def handle_out(
        "xfer_response" = event,
        %{"target_session_id" => target_session_id} = payload,
        socket
      ) do
    if target_session_id == socket.assigns.session_id do
      push(socket, event, payload)
    end

    {:noreply, socket}
  end

  def handle_info({:begin_tracking, session_id, xfer_code}, socket) do
    push(socket, "presence_state", Presence.list(socket))
    {:ok, _} = Presence.track(socket, session_id, %{xfer_code: xfer_code})
    {:noreply, socket}
  end

  def handle_info(:channel_expired, socket) do
    push(socket, "xfer_expired", %{})
    GenServer.cast(self(), :close)
    {:noreply, socket}
  end
end
