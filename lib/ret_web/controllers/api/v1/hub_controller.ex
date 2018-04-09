defmodule RetWeb.Api.V1.HubController do
  use RetWeb, :controller

  alias Ret.Hub
  alias Ret.Repo

  def create(conn, %{"hub" => hub_params}) do
    {result, hub} =
      %Hub{}
      |> Hub.changeset(hub_params)
      |> Repo.insert()

    case result do
      :ok -> render(conn, "create.json", hub: hub)
      :error -> conn |> send_resp(422, "invalid hub")
    end
  end
end
