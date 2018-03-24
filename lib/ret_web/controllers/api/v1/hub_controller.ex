defmodule RetWeb.Api.V1.HubController do
  use RetWeb, :controller
  import Ecto.Query

  alias Ret.Hub
  alias Ret.Repo

  def create(conn, %{"hub" => hub_params}) do
    hub_sid = hub_params["hub_id"]

    hub_attrs = hub_params
                |> Map.delete("hub_id")
                |> Map.put("hub_sid", hub_sid)

    { result, hub } = case Repo.get_by(Hub, hub_sid: hub_params["hub_id"]) do
      nil -> Hub.changeset(%Hub{}, hub_attrs) |> Repo.insert
      hub -> { :ok, hub }
    end

    case result do
      :ok -> render(conn, "create.json", hub: hub)
      :error -> conn |> send_resp(422, "invalid hub")
    end
  end

  def show(conn, %{ "id" => id }) do
    hub = Repo.get_by(Hub, hub_sid: id)
    render(conn, "show.json", hub: hub)
  end
end
