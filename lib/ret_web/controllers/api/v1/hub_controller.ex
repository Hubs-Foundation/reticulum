defmodule RetWeb.Api.V1.HubController do
  use RetWeb, :controller
  import RetWeb.ApiHelpers

  alias Ret.{Hub, Scene, SceneListing, Repo}

  import Canada, only: [can?: 2]
  import Ecto.Query, only: [where: 3, preload: 2]

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  # Only allow access to remove hubs with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [:delete])

  @show_request_schema %{
                         "type" => "object",
                         "properties" => %{
                           "created_by_account_email" => %{
                             "type" => "string",
                             "format" => "email"
                           },
                           "hub_sids" => %{
                             "type" => "array",
                             "items" => %{
                               "type" => "string"
                             }
                           }
                         }
                       }
                       |> ExJsonSchema.Schema.resolve()

  def show(conn, params) do
    exec_api_show(conn, params, @show_request_schema, &render_hub_records/2)
  end

  defp with_created_by_account(query, %Ret.Account{} = account) do
    query
    |> preload(:created_by_account)
    |> where([hub], hub.created_by_account_id == ^account.account_id)
  end

  defp with_created_by_account(query, _params) do
    query
  end

  defp filter_by_created_by_account_email(query, %{"created_by_account_email" => email}) do
    created_by_account = Ret.Account.account_for_email(email)
    query |> with_created_by_account(created_by_account)
  end

  defp filter_by_created_by_account_email(query, _params) do
    query
  end

  defp filter_by_hub_sids(query, %{"hub_sids" => hub_sids}) do
    query |> filter_by_hub_sids(hub_sids)
  end

  defp filter_by_hub_sids(query, hub_sids) when is_list(hub_sids) do
    query |> where([hub], hub.hub_sid in ^hub_sids)
  end

  defp filter_by_hub_sids(query, _params) do
    query
  end

  defp filter_by_can_join(hubs, %Ret.Account{} = account) do
    hubs
    |> Ret.Repo.preload(:hub_bindings)
    |> Enum.filter(fn hub ->
      account |> can?(join_hub(hub))
    end)
  end

  defp filter_by_can_join(_hubs, _account) do
    []
  end

  defp render_hub_records(conn, params) do
    account = Guardian.Plug.current_resource(conn)

    hubs =
      Ret.Hub
      |> filter_by_created_by_account_email(params)
      |> filter_by_hub_sids(params)
      |> Ret.Repo.all()
      |> filter_by_can_join(account)

    views =
      hubs
      |> Enum.map(fn hub ->
        Phoenix.View.render(RetWeb.Api.V1.HubView, "show.json", %{hub: hub}) |> Map.get(:hubs) |> hd
      end)

    {:ok, views}
  end

  def create(conn, %{"hub" => %{"scene_id" => scene_id}} = params) do
    scene = Scene.scene_or_scene_listing_by_sid(scene_id)

    %Hub{}
    |> Hub.changeset(scene, params["hub"])
    |> exec_create(conn)
  end

  def create(conn, %{"hub" => _hub_params} = params) do
    scene_listing = SceneListing.get_random_default_scene_listing()

    %Hub{}
    |> Hub.changeset(scene_listing, params["hub"])
    |> exec_create(conn)
  end

  defp exec_create(hub_changeset, conn) do
    account = Guardian.Plug.current_resource(conn)

    if account |> can?(create_hub(nil)) do
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

  def update(conn, %{"id" => hub_sid, "hub" => hub_params}) do
    account = Guardian.Plug.current_resource(conn)

    case Hub
         |> Repo.get_by(hub_sid: hub_sid)
         |> Repo.preload([:created_by_account, :hub_bindings, :hub_role_memberships]) do
      %Hub{} = hub ->
        if account |> can?(update_hub(hub)) do
          update_with_hub(conn, account, hub, hub_params)
        else
          conn |> send_resp(401, "You cannot update this hub")
        end

      _ ->
        conn |> send_resp(404, "not found")
    end
  end

  defp update_with_hub(conn, account, hub, hub_params) do
    if is_nil(hub_params["scene_id"]) do
      update_with_hub_and_scene(conn, account, hub, nil, hub_params)
    else
      case Scene.scene_or_scene_listing_by_sid(hub_params["scene_id"]) do
        nil -> conn |> send_resp(422, "scene not found")
        scene -> update_with_hub_and_scene(conn, account, hub, scene, hub_params)
      end
    end
  end

  defp update_with_hub_and_scene(conn, account, hub, scene, hub_params) do
    changeset =
      hub
      |> Hub.add_attrs_to_changeset(hub_params)
      |> maybe_add_new_scene(scene)
      |> maybe_add_member_permissions(hub, hub_params)
      |> maybe_add_promotion(account, hub, hub_params)

    hub = changeset |> Repo.update!() |> Repo.preload(Hub.hub_preloads())

    conn |> render("show.json", %{hub: hub, embeddable: account |> can?(embed_hub(hub))})
  end

  defp maybe_add_new_scene(changeset, nil), do: changeset

  defp maybe_add_new_scene(changeset, scene), do: changeset |> Hub.add_new_scene_to_changeset(scene)

  defp maybe_add_member_permissions(changeset, hub, %{"member_permissions" => %{}} = hub_params),
    do: changeset |> Hub.add_member_permissions_update_to_changeset(hub, hub_params)

  defp maybe_add_member_permissions(changeset, _hub, _), do: changeset

  defp maybe_add_promotion(changeset, account, hub, %{"allow_promotion" => _} = hub_params),
    do: changeset |> Hub.maybe_add_promotion_to_changeset(account, hub, hub_params)

  defp maybe_add_promotion(changeset, _account, _hub, _), do: changeset

  def delete(conn, %{"id" => hub_sid}) do
    Hub
    |> Repo.get_by(hub_sid: hub_sid)
    |> Hub.changeset_for_entry_mode(:deny)
    |> Repo.update!()

    conn |> send_resp(200, "OK")
  end
end
