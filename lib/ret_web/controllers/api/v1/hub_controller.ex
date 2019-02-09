defmodule RetWeb.Api.V1.HubController do
  use RetWeb, :controller

  alias Ret.{Hub, Scene, Repo}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  # Only allow access with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [:delete])

  def create(conn, %{"hub" => %{"scene_id" => scene_id}} = params) do
    scene = Scene.scene_or_scene_listing_by_sid(scene_id)

    %Hub{}
    |> Hub.changeset(scene, params["hub"])
    |> exec_create(conn)
  end

  def create(conn, %{"hub" => _hub_params} = params) do
    %Hub{}
    |> Hub.changeset(nil, params["hub"])
    |> exec_create(conn)
  end

  defp exec_create(hub_changeset, conn) do
    {result, hub} =
      hub_changeset
      |> Hub.add_account_to_changeset(Guardian.Plug.current_resource(conn))
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
