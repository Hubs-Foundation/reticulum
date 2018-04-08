defmodule RetWeb.HubChannel do
  @moduledoc "Ret Web Channel for Hubs"

  use RetWeb, :channel

  alias Ret.{Hub, Repo}

  def join("hub:" <> hub_sid, _payload, socket) do
    hub = Repo.get_by(Hub, hub_sid: hub_sid)

    case hub do
      nil ->
        {:error, %{message: "No such Hub #{hub_sid}"}}

      _ ->
        with response <- RetWeb.Api.V1.HubView.render("show.json", %{hub: hub}),
             socket <- assign(socket, :hub_sid, hub_sid) do
          {:ok, response, socket}
        end
    end
  end

  def handle_in("events:entered", payload, socket) do
    socket
    |> assign(:entry_event_payload, payload)
    |> assign(:entry_event_received_at, DateTime.utc_now())

    {:noreply, socket}
  end

  def handle_in(_message, _payload, socket) do
    {:noreply, socket}
  end
end
