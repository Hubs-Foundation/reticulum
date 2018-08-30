defmodule RetWeb.AuthChannel do
  @moduledoc "Ret Web Channel for Authentication"

  use RetWeb, :channel

  alias Ret.{Statix}
  alias RetWeb.{Presence}

  intercept(["link_response"])

  def join("auth:" <> key, _payload, socket) do
    # Expire channel in 5 minutes
    Process.send_after(self(), :channel_expired, 60 * 1000 * 5)

    # Rate limit joins to reduce attack surface
    :timer.sleep(3000)

    Statix.increment("ret.channels.auth.joins.ok")
    {:ok, "{}", socket}
  end

  def handle_in("auth_request", %{"email" => email}, socket) do
    # Send email

    {:noreply, socket}
  end

  def handle_in("auth_verified" = event, _payload, socket) do
    # Generate JWT, respond, close after 5 seconds
    Process.send_after(self(), :close_channel, 1000 * 5)
    token = "foo"

    {:reply, {:ok, %{"token" => token}}, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  def handle_info(:close_channel, socket) do
    GenServer.cast(self(), :close)
    {:noreply, socket}
  end
end
