defmodule Ret.Api.Rooms do
  @moduledoc "Functions for accessing rooms in an authenticated way"

  alias Ret.{Account, Hub, Repo}
  alias RetWeb.Api.V1.HubView
  alias Ret.Api.{Credentials}

  import Canada, only: [can?: 2]

  def authed_get_embed_token(%Credentials{} = credentials, hub) do
    if can?(credentials, embed_hub(hub)) do
      {:ok, hub.embed_token}
    else
      {:ok, nil}
    end
  end

  def authed_get_rooms_created_by(%Account{} = account, %Credentials{} = credentials, params) do
    if can?(credentials, get_rooms_created_by(account)) do
      {:ok, Hub.get_my_rooms(account, params)}
    else
      {:error, :invalid_credentials}
    end
  end

  def authed_get_favorite_rooms_of(%Account{} = account, %Credentials{} = credentials, params) do
    if can?(credentials, get_favorite_rooms_of(account)) do
      {:ok, Hub.get_my_rooms(account, params)}
    else
      {:error, :invalid_credentials}
    end
  end

  def authed_get_public_rooms(%Credentials{} = credentials, params) do
    if can?(credentials, get_public_rooms(nil)) do
      {:ok, Hub.get_public_rooms(params)}
    else
      {:error, :invalid_credentials}
    end
  end

  defp do_create_room(%Account{} = account, params) do
    random_name = Ret.RandomRoomNames.generate_room_name()
    params = Map.put(params, :name, Map.get(params, :name, random_name))

    with {:ok, hub} <- Hub.create(params),
         {:ok, hub} <-
           hub
           |> Hub.add_attrs_to_changeset(params)
           |> Hub.maybe_add_member_permissions(hub, params)
           |> Hub.maybe_add_promotion(account, hub, params)
           |> Hub.maybe_add_new_scene_to_changeset(params)
           |> Repo.update() do
      hub
      |> Repo.preload(Hub.hub_preloads())
      |> Hub.changeset_for_creator_assignment(account, hub.creator_assignment_token)
      |> Repo.update()
    end
  end

  defp do_create_room(:reticulum_app_token, params) do
    params = Map.put(params, :name, Map.get(params, :name, Ret.RandomRoomNames.generate_room_name()))

    with {:ok, hub} <- Hub.create(params) do
      hub
      |> Hub.add_attrs_to_changeset(params)
      |> Hub.maybe_add_member_permissions(hub, params)
      |> Hub.maybe_add_new_scene_to_changeset(params)
      |> Repo.update()
    end
  end

  def authed_create_room(%Credentials{resource: resource} = credentials, params) do
    if can?(credentials, create_room(nil)) do
      do_create_room(resource, params)
    else
      {:error, :invalid_credentials}
    end
  end

  def authed_update_room(hub, %Credentials{resource: resource} = credentials, params) do
    if can?(credentials, update_room(hub)) do
      do_update_room(hub, resource, params)
    else
      {:error, :invalid_credentials}
    end
  end

  defp do_update_room(hub, resource, params) do
    update_room_with_resource(hub, resource, params)
  end

  # TODO: DRY up the update_room flow
  defp update_room_with_resource(hub, :reticulum_app_token, params) do
    hub
    |> Hub.add_attrs_to_changeset(params)
    |> Hub.maybe_add_member_permissions(hub, params)
    |> Hub.maybe_add_new_scene_to_changeset(params)
    |> try_do_update_room(:reticulum_app_token)
  end

  defp update_room_with_resource(hub, %Account{} = account, params) do
    hub
    |> Hub.add_attrs_to_changeset(params)
    |> Hub.maybe_add_member_permissions(hub, params)
    |> Hub.maybe_add_promotion(account, hub, params)
    |> Hub.maybe_add_new_scene_to_changeset(params)
    |> try_do_update_room(account)
  end

  defp try_do_update_room({:error, reason}, _) do
    {:error, reason}
  end

  defp try_do_update_room(changeset, :reticulum_app_token) do
    case changeset |> Repo.update() do
      {:error, changeset} ->
        {:error, changeset}

      {:ok, hub} ->
        hub = Repo.preload(hub, Hub.hub_preloads())

        case broadcast_hub_refresh(hub, :reticulum_app_token) do
          {:error, reason} -> {:error, reason}
          :ok -> {:ok, hub}
        end
    end
  end

  defp try_do_update_room(changeset, account) do
    case changeset |> Repo.update() do
      {:error, changeset} ->
        {:error, changeset}

      {:ok, hub} ->
        hub = Repo.preload(hub, Hub.hub_preloads())

        case broadcast_hub_refresh(hub, account) do
          {:error, reason} -> {:error, reason}
          :ok -> {:ok, hub}
        end
    end
  end

  defp broadcast_hub_refresh(hub, :reticulum_app_token) do
    payload =
      HubView.render("show.json", %{
        hub: hub,
        embeddable: true
      })
      |> Map.put(:stale_fields, [
        # TODO: Only include fields that have changed in stale_fields
        "name",
        "description",
        "member_permissions",
        "room_size",
        "allow_promotion",
        "scene"
      ])

    RetWeb.Endpoint.broadcast("hub:" <> hub.hub_sid, "hub_refresh", payload)
  end

  defp broadcast_hub_refresh(hub, %Account{} = account) do
    payload =
      HubView.render("show.json", %{
        hub: hub,
        embeddable: account |> can?(embed_hub(hub))
      })
      |> Map.put(:stale_fields, [
        # TODO: Only include fields that have changed in stale_fields
        "name",
        "description",
        "member_permissions",
        "room_size",
        "allow_promotion",
        "scene"
      ])

    RetWeb.Endpoint.broadcast("hub:" <> hub.hub_sid, "hub_refresh", payload)
  end
end
