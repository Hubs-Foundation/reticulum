defmodule RetWeb.Resolvers.RoomResolver do
  alias Ret.{Hub, Repo, Scene, SceneListing}
  import Canada, only: [can?: 2]
  import RetWeb.ApiEctoErrorHelpers
  import Ecto.Changeset, only: [put_assoc: 3, change: 1]

  def my_rooms(_parent, args, %{context: %{account: account}}) do
    {:ok, Hub.get_my_rooms(account, args)}
  end

  def my_rooms(_parent, _args, _resolutions) do
    {:error, "Not authorized"}
  end

  def favorite_rooms(_parent, args, %{context: %{account: account}}) do
    {:ok, Hub.get_favorite_rooms(account, args)}
  end

  def favorite_rooms(_parent, _args, _resolutions) do
    {:error, "Not authorized"}
  end

  def public_rooms(_parent, args, _resolutions) do
    {:ok, Hub.get_public_rooms(args)}
  end

  def create_room(_parent, args, %{context: %{account: account}}) do
    {:ok, hub} = Hub.create(args)

    hub
    |> Repo.preload(Hub.hub_preloads())
    |> Hub.changeset_for_creator_assignment(account, hub.creator_assignment_token)
    |> Repo.update!()

    {:ok, hub}
  end

  def create_room(_parent, args, _resolutions) do
    Hub.create(args)
  end

  def embed_token(hub, _args, %{context: %{account: account}}) do
    if account |> can?(embed_hub(hub)) do
      {:ok, hub.embed_token}
    else
      {:ok, nil}
    end
  end

  def embed_token(_hub, _args, _resolutions) do
    {:ok, nil}
  end

  def port(_hub, _args, _resolutions) do
    {:ok, Hub.janus_port()}
  end

  def turn(_hub, _args, _resolutions) do
    {:ok, Hub.generate_turn_info()}
  end

  def member_permissions(hub, _args, _resolutions) do
    {:ok, Hub.member_permissions_for_hub_as_atoms(hub)}
  end

  def room_size(hub, _args, _resolutions) do
    {:ok, Hub.room_size_for(hub)}
  end

  def member_count(hub, _args, _resolutions) do
    {:ok, Hub.member_count_for(hub)}
  end

  def lobby_count(hub, _args, _resolutions) do
    {:ok, Hub.lobby_count_for(hub)}
  end

  def scene(hub, _args, _resolutions) do
    {:ok, Hub.scene_or_scene_listing_for(hub)}
  end

  def update_room(_, %{id: hub_sid} = args, %{context: %{account: account}}) do
    hub =
      Hub
      |> Repo.get_by(hub_sid: hub_sid)
      |> Repo.preload([:hub_role_memberships, :hub_bindings])

    case hub do
      nil ->
        {:error, "Cannot find room with id " <> hub_sid}

      _ ->
        case can?(account, update_roles(hub)) do
          false ->
            {:error, "Account does not have permission to update this hub."}

          true ->
            scene_id = Map.get(args, :scene_id, nil)
            scene_or_scene_listing = Hub.get_scene_or_scene_listing_by_id(scene_id)

            if scene_id && is_nil(scene_or_scene_listing) do
              {:error, "Cannot find scene with id " <> scene_id}
            else
              changeset =
                if scene_or_scene_listing,
                  do: Hub.changeset_for_new_scene(hub, scene_or_scene_listing),
                  else: change(hub)

              changeset = Hub.add_attrs_to_changeset(changeset, args)

              # TODO: Member permissions #              |> Hub.add_member_permissions_to_changeset(args)
              # TODO: Promotions         #              |> Hub.maybe_add_promotion_to_changeset(account, hub, args)

              case changeset do
                %{valid?: false} ->
                  {:error,
                   %{
                     message: "Changeset errors occurred",
                     code: :schema_errors,
                     errors: to_api_errors(changeset)
                   }}

                _ ->
                  updated_hub =
                    changeset
                    |> Repo.update!()
                    |> Repo.preload(Hub.hub_preloads())

                  # TODO: Broadcast changes on hub_channel so room occupants know about changes
                  {:ok, updated_hub}
              end
            end
        end
    end
  end
end
