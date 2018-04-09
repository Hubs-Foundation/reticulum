defmodule RetWeb.HubChannel do
  @moduledoc "Ret Web Channel for Hubs"

  use RetWeb, :channel

  alias Ret.{Hub, Repo, SessionStat}

  def join("hub:" <> hub_sid, _payload, socket) do
    hub = Repo.get_by(Hub, hub_sid: hub_sid)

    case hub do
      nil ->
        {:error, %{message: "No such Hub #{hub_sid}"}}

      _ ->
        with socket <- assign(socket, :hub_sid, hub_sid),
             session_id <- socket.assigns.session_id,
             started_at <- socket.assigns.started_at,
             stat_attrs <- %{session_id: session_id, started_at: started_at},
             changeset <- %SessionStat{} |> SessionStat.changeset(stat_attrs),
             response <- RetWeb.Api.V1.HubView.render("show.json", %{hub: hub}) do
          Repo.insert(changeset)

          {:ok, response, socket}
        end
    end
  end

  def handle_in("events:entered", payload, socket) do
    socket
    |> SessionStat.stat_query_for_socket()
    |> Repo.update_all(
      set: [entered_event_payload: payload, entered_event_received_at: DateTime.utc_now()]
    )

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
end
