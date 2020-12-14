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
      {:ok, Hub.get_favorite_rooms(account, params)}
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

  def authed_create_room(%Credentials{} = credentials, params) do
    if can?(credentials, create_room(nil)) do
      Hub.create_room(params, credentials.account)
    else
      {:error, :invalid_credentials}
    end
  end

  def authed_update_room(hub_sid, %Credentials{} = credentials, params) do
    hub = Hub |> Repo.get_by(hub_sid: hub_sid) |> Repo.preload([:hub_role_memberships, :hub_bindings])

    if is_nil(hub) do
      {:error, "Cannot find room with id: " <> hub_sid}
    else
      if can?(credentials, update_room(hub)) do
        do_update_room(hub, credentials, params)
      else
        {:error, :invalid_credentials}
      end
    end
  end

  defp do_update_room(hub, %Credentials{subject_type: :app}, params) do
    hub
    |> Repo.preload(Hub.hub_preloads())
    |> Hub.add_attrs_to_changeset(params)
    |> Hub.maybe_add_member_permissions(hub, params)
    |> Hub.add_scene_changes_to_changeset(params)
    |> try_do_update_room(:reticulum_app_token)
  end

  defp do_update_room(hub, %Credentials{subject_type: :account, account: account}, params) do
    hub
    |> Repo.preload(Hub.hub_preloads())
    |> Hub.add_attrs_to_changeset(params)
    |> Hub.maybe_add_member_permissions(hub, params)
    |> Hub.maybe_add_promotion(account, hub, params)
    |> Hub.add_scene_changes_to_changeset(params)
    |> try_do_update_room(account)
  end

  defp try_do_update_room({:error, reason}, _) do
    {:error, reason}
  end

  defp try_do_update_room(changeset, subject) do
    case changeset |> Repo.update() do
      {:error, changeset} ->
        {:error, changeset}

      {:ok, hub} ->
        hub = Repo.preload(hub, Hub.hub_preloads())

        case broadcast_hub_refresh(hub, subject, Map.keys(changeset.changes) |> Enum.map(&Atom.to_string(&1))) do
          {:error, reason} -> {:error, reason}
          :ok -> {:ok, hub}
        end
    end
  end

  defp broadcast_hub_refresh(hub, subject, stale_fields) do
    payload =
      HubView.render("show.json", %{
        hub: hub,
        embeddable: subject |> can?(embed_hub(hub))
      })
      |> Map.put(:stale_fields, stale_fields)

    RetWeb.Endpoint.broadcast("hub:" <> hub.hub_sid, "hub_refresh", payload)
  end
end
