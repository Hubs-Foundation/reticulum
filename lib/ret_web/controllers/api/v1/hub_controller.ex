defmodule RetWeb.Api.V1.HubController do
  use RetWeb, :controller
  import Ecto.Query

  alias Ret.Hub
  alias Ret.Repo

  def create(conn, %{"hub" => hub_params}) do
    hub_attrs = Map.delete(hub_params, "hub_id")

    { :ok, hub } = case Repo.get_by(Hub, hub_sid: hub_params["hub_id"]) do
      nil ->
        Hub.changeset(%Hub{hub_sid: hub_params["hub_id"]}, hub_attrs)
        |> Repo.insert
      hub -> { :ok, hub }
    end

    render(conn, "create.json", hub: hub)
  end

  def show(conn, %{ "id" => id }) do
    hub = Repo.get_by(Hub, hub_sid: id)
    render(conn, "show.json", hub: hub)
  end
end
