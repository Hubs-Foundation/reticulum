defmodule RetWeb.Api.V1.HubController do
  use RetWeb, :controller

  alias Ret.{Account, Hub, PermsToken, Scene, SceneListing, Repo}

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  # Only allow access to remove hubs with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [:delete])

  def create(conn, %{"hub" => %{"scene_id" => scene_id}} = params) do
    scene = Scene.scene_or_scene_listing_by_sid(scene_id)

    %Hub{}
    |> Hub.changeset(scene, params["hub"])
    |> exec_create(conn, params)
  end

  def create(conn, %{"hub" => _hub_params} = params) do
    scene_listing = SceneListing.get_random_default_scene_listing()

    %Hub{}
    |> Hub.changeset(scene_listing, params["hub"])
    |> exec_create(conn, params)
  end

  defp exec_create(hub_changeset, conn, params) do
    account = Guardian.Plug.current_resource(conn)

    if can_create_hub?(account, params["perms_token"]) do
      {result, hub} =
        hub_changeset
        |> Hub.add_account_to_changeset(account)
        |> Repo.insert()

      case result do
        :ok -> render(conn, "create.json", hub: hub)
        :error -> conn |> send_resp(422, "invalid hub")
      end
    else
      conn |> send_resp(401, "unauthorized")
    end
  end

  def delete(conn, %{"id" => hub_sid}) do
    Hub
    |> Repo.get_by(hub_sid: hub_sid)
    |> Hub.changeset_for_entry_mode(:deny)
    |> Repo.update!()

    conn |> send_resp(200, "OK")
  end

  defp can_create_hub?(_account, perms_token) when perms_token != nil do
    case PermsToken.decode_and_verify(perms_token) do
      {:ok, %{"create_hub" => true}} -> true
      _ -> false
    end
  end

  # Deprecated, old clients which do not pass token fall back on dynamic permissions
  defp can_create_hub?(account, _perms_token),
    do: account |> Account.get_global_perms_for_account() |> Map.get(:hub_create)
end
