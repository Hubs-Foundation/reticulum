defmodule RetWeb.HubChannel do
  @moduledoc "Ret Web Channel for Hubs"

  use RetWeb, :channel

  alias Ret.{Hub, Repo, SessionStat, Statix}
  alias RetWeb.{Presence}

  def join("hub:" <> hub_sid, _payload, socket) do
    Hub
    |> Repo.get_by(hub_sid: hub_sid)
    |> join_with_hub(socket)
  end

  def handle_in("events:entered", %{"initialOccupantCount" => occupant_count} = payload, socket) do
    socket
    |> handle_max_occupant_update(occupant_count)
    |> handle_entered_event(payload)

    Statix.increment("ret.channels.hub.event_entered", 1)

    {:noreply, socket}
  end

  def handle_in("events:entered", payload, socket) do
    handle_entered_event(socket, payload)

    Statix.increment("ret.channels.hub.event_entered", 1)

    {:noreply, socket}
  end

  def handle_in(_message, _payload, socket) do
    {:noreply, socket}
  end

  def handle_info({:begin_tracking, session_id, hub_sid}, socket) do
    {:ok, _} = Presence.track(socket, session_id, %{hub_id: hub_sid})
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    socket
    |> SessionStat.stat_query_for_socket()
    |> Repo.update_all(set: [ended_at: NaiveDateTime.utc_now()])

    :ok
  end

  defp join_with_hub(%Hub{} = hub, socket) do
    with socket <- assign(socket, :hub_sid, hub.hub_sid),
         response <- RetWeb.Api.V1.HubView.render("show.json", %{hub: hub}) do
      existing_stat_count =
        socket
        |> SessionStat.stat_query_for_socket()
        |> Repo.all()
        |> length

      unless existing_stat_count > 0 do
        with session_id <- socket.assigns.session_id,
             started_at <- socket.assigns.started_at,
             stat_attrs <- %{session_id: session_id, started_at: started_at},
             changeset <- %SessionStat{} |> SessionStat.changeset(stat_attrs) do
          Repo.insert(changeset)
        end
      end

      send(self(), {:begin_tracking, socket.assigns.session_id, hub.hub_sid})

      Statix.increment("ret.channels.hub.joins.ok")

      {:ok, response, socket}
    end
  end

  defp join_with_hub(nil, _socket) do
    Statix.increment("ret.channels.hub.joins.not_found")

    {:error, %{message: "No such Hub"}}
  end

  defp handle_entered_event(socket, payload) do
    with stat_attributes <- [
           entered_event_payload: payload,
           entered_event_received_at: NaiveDateTime.utc_now()
         ] do
      socket
      |> SessionStat.stat_query_for_socket()
      |> Repo.update_all(set: stat_attributes)
    end
  end

  defp handle_max_occupant_update(socket, occupant_count) do
    with hub <- Repo.get_by(Hub, hub_sid: socket.assigns.hub_sid),
         max_occupant_count <- max(occupant_count, hub.max_occupant_count) do
      hub
      |> Hub.changeset_for_new_max_occupants(max_occupant_count)
      |> Repo.update!()

      socket
    end
  end
end
