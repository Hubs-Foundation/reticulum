defmodule RetWeb.HubChannel do
  @moduledoc "Ret Web Channel for Hubs"

  use RetWeb, :channel

  alias Ret.{Hub, Repo, SessionStat}

  def join("hub:" <> hub_sid, _payload, socket) do
    hub = Repo.get_by(Hub, hub_sid: hub_sid)
    socket |> join_with_hub(hub)
  end

  def handle_in("events:entered", %{"initialOccupantCount" => occupant_count} = payload, socket) do
    socket
    |> handle_max_occupant_update(occupant_count)
    |> handle_entered_event(payload)

    {:noreply, socket}
  end

  def handle_in("events:entered", payload, socket) do
    handle_entered_event(socket, payload)

    {:noreply, socket}
  end

  def handle_in(_message, _payload, socket) do
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    socket
    |> SessionStat.stat_query_for_socket()
    |> Repo.update_all(set: [ended_at: DateTime.utc_now()])

    :ok
  end

  defp join_with_hub(socket, %Hub{} = hub) do
    with socket <- assign(socket, :hub_sid, hub.hub_sid),
         session_id <- socket.assigns.session_id,
         started_at <- socket.assigns.started_at,
         stat_attrs <- %{session_id: session_id, started_at: started_at},
         changeset <- %SessionStat{} |> SessionStat.changeset(stat_attrs),
         response <- RetWeb.Api.V1.HubView.render("show.json", %{hub: hub}) do
      Repo.insert(changeset)

      {:ok, response, socket}
    end
  end

  defp join_with_hub(socket, nil) do
    {:error, %{message: "No such Hub"}}
  end

  defp handle_entered_event(socket, payload) do
    with stat_attributes <- [
           entered_event_payload: payload,
           entered_event_received_at: DateTime.utc_now()
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
