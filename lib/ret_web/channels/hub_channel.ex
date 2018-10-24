defmodule RetWeb.HubChannel do
  @moduledoc "Ret Web Channel for Hubs"

  use RetWeb, :channel

  alias Ret.{Hub, Repo, RoomObject, SessionStat, Statix}
  alias RetWeb.{Presence}

  def join("hub:" <> hub_sid, %{"profile" => profile, "context" => context}, socket) do
    socket |> assign(:profile, profile) |> assign(:context, context) |> perform_join(hub_sid)
  end

  # TODO remove when client is updated to always send display name on join
  def join("hub:" <> hub_sid, _payload, socket) do
    socket |> assign(:profile, %{}) |> assign(:context, %{}) |> perform_join(hub_sid)
  end

  defp perform_join(socket, hub_sid) do
    Hub
    |> Repo.get_by(hub_sid: hub_sid)
    |> Repo.preload(scene: [:model_owned_file, :screenshot_owned_file])
    |> Hub.ensure_valid_entry_code!()
    |> join_with_hub(socket)
  end

  def handle_in("events:entered", %{"initialOccupantCount" => occupant_count} = payload, socket) do
    socket =
      socket
      |> handle_max_occupant_update(occupant_count)
      |> handle_entered_event(payload)

    Statix.increment("ret.channels.hub.event_entered", 1)

    {:noreply, socket}
  end

  def handle_in("events:entered", payload, socket) do
    socket = socket |> handle_entered_event(payload)

    Statix.increment("ret.channels.hub.event_entered", 1)

    {:noreply, socket}
  end

  def handle_in("events:object_spawned", %{"object_type" => object_type}, socket) do
    socket = socket |> handle_object_spawned(object_type)

    Statix.increment("ret.channels.hub.objects_spawned", 1)

    {:noreply, socket}
  end

  def handle_in("events:request_support", _payload, socket) do
    hub = socket |> hub_for_socket
    Task.async(fn -> hub |> Ret.Support.request_support_for_hub() end)

    {:noreply, socket}
  end

  def handle_in("events:profile_updated", %{"profile" => profile}, socket) do
    socket = socket |> assign(:profile, profile) |> broadcast_presence_update
    {:noreply, socket}
  end

  def handle_in("naf" = event, payload, socket) do
    broadcast_from!(socket, event, payload)
    {:noreply, socket}
  end

  def handle_in("message" = event, payload, socket) do
    broadcast!(socket, event, payload |> Map.put(:session_id, socket.assigns.session_id))
    {:noreply, socket}
  end

  def handle_in("pin", %{"id" => room_object_sid, "gltf_node" => gltf_node}, socket) do
    hub = socket |> hub_for_socket
    RoomObject.perform_pin!(hub, %{room_object_sid: room_object_sid, gltf_node: gltf_node})

    {:noreply, socket}
  end

  def handle_in("unpin", %{"id" => room_object_sid}, socket) do
    hub = socket |> hub_for_socket
    RoomObject.perform_unpin(hub, room_object_sid)

    {:noreply, socket}
  end

  def handle_in(_message, _payload, socket) do
    {:noreply, socket}
  end

  def handle_info({:begin_tracking, session_id, _hub_sid}, socket) do
    {:ok, _} = Presence.track(socket, session_id, socket |> presence_meta_for_socket)
    push(socket, "presence_state", socket |> Presence.list())

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    socket
    |> SessionStat.stat_query_for_socket()
    |> Repo.update_all(set: [ended_at: NaiveDateTime.utc_now()])

    :ok
  end

  defp broadcast_presence_update(socket) do
    Presence.update(socket, socket.assigns.session_id, socket |> presence_meta_for_socket)
    socket
  end

  defp presence_meta_for_socket(socket) do
    socket.assigns |> Map.take([:presence, :profile, :context])
  end

  defp join_with_hub(%Hub{entry_mode: :deny}, _socket) do
    {:error, %{message: "Hub no longer accessible", reason: "closed"}}
  end

  defp join_with_hub(%Hub{} = hub, socket) do
    with socket <- socket |> assign(:hub_sid, hub.hub_sid) |> assign(:presence, :lobby),
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
    stat_attributes = [entered_event_payload: payload, entered_event_received_at: NaiveDateTime.utc_now()]

    # Flip context to have HMD if entered with display type
    socket =
      with %{"entryDisplayType" => display} when is_binary(display) and display != "Screen" <- payload,
           %{context: context} when is_map(context) <- socket.assigns do
        socket |> assign(:context, context |> Map.put("hmd", true))
      else
        _ -> socket
      end

    socket
    |> SessionStat.stat_query_for_socket()
    |> Repo.update_all(set: stat_attributes)

    socket |> assign(:presence, :room) |> broadcast_presence_update
  end

  defp handle_max_occupant_update(socket, occupant_count) do
    socket
    |> hub_for_socket
    |> Hub.changeset_for_new_seen_occupant_count(occupant_count)
    |> Repo.update!()

    socket
  end

  defp handle_object_spawned(socket, object_type) do
    socket
    |> hub_for_socket
    |> Hub.changeset_for_new_spawned_object_type(object_type)
    |> Repo.update!()

    socket
  end

  defp hub_for_socket(socket) do
    Repo.get_by(Hub, hub_sid: socket.assigns.hub_sid)
  end
end
