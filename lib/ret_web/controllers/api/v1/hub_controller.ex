defmodule RetWeb.Api.V1.HubController do
  use RetWeb, :controller

  alias Ret.Hub
  alias Ret.Repo

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  # Only allow access with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [:delete])

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

  def delete(conn, %{"id" => hub_sid}) do
    Hub
    |> Repo.get_by(hub_sid: hub_sid)
    |> Hub.changeset_to_deny_entry()
    |> Repo.update!()

    conn |> send_resp(200, "OK")
  end
end
