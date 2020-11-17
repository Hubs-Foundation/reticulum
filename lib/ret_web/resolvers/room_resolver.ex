defmodule RetWeb.Resolvers.RoomResolver do
  @moduledoc """
  Resolvers for room queries and mutations via the graphql API
  """
  alias Ret.Hub
  alias Ret.Api.Credentials
  import RetWeb.Resolvers.ResolverError, only: [resolver_error: 2]

  def my_rooms(_parent, _args, %{
        context: %{
          credentials: %Credentials{
            subject_type: :app
          }
        }
      }) do
    resolver_error(:not_implemented, "Not implemented for app tokens")
  end

  def my_rooms(_parent, args, %{
        context: %{
          credentials:
            %Credentials{
              subject_type: :account,
              account: account
            } = credentials
        }
      }) do
    Ret.Api.Rooms.authed_get_rooms_created_by(account, credentials, args)
  end

  def my_rooms(_parent, _args, _resolutions) do
    resolver_error(:unauthorized, "Unauthorized access")
  end

  def favorite_rooms(_parent, _args, %{
        context: %{
          credentials: %Credentials{
            subject_type: :app
          }
        }
      }) do
    resolver_error(:not_implemented, "Not implemented for app tokens")
  end

  def favorite_rooms(_parent, args, %{
        context: %{
          credentials:
            %Credentials{
              subject_type: :account,
              account: account
            } = credentials
        }
      }) do
    Ret.Api.Rooms.authed_get_favorite_rooms_of(account, credentials, args)
  end

  def favorite_rooms(_parent, _args, _resolutions) do
    resolver_error(:unauthorized, "Unauthorized access")
  end

  def public_rooms(_parent, args, %{
        context: %{
          credentials: %Credentials{} = credentials
        }
      }) do
    Ret.Api.Rooms.authed_get_public_rooms(credentials, args)
  end

  def public_rooms(_, _, _) do
    resolver_error(:unauthorized, "Unauthorized access")
  end

  def create_room(_parent, args, %{
        context: %{
          credentials: %Credentials{} = credentials
        }
      }) do
    Ret.Api.Rooms.authed_create_room(credentials, args)
  end

  def create_room(_parent, _args, _resolutions) do
    resolver_error(:unauthorized, "Unauthorized access")
  end

  def embed_token(hub, _args, %{
        context: %{
          credentials: %Credentials{} = credentials
        }
      }) do
    Ret.Api.Rooms.authed_get_embed_token(credentials, hub)
  end

  def embed_token(_hub, _args, _resolutions) do
    resolver_error(:unauthorized, "Unauthorized access")
  end

  def port(_hub, _args, _resolutions) do
    # No permission check needed
    {:ok, Hub.janus_port()}
  end

  def turn(_hub, _args, _resolutions) do
    # No permission check needed
    {:ok, Hub.generate_turn_info()}
  end

  def member_permissions(hub, _args, _resolutions) do
    # No permission check needed
    {:ok, Hub.member_permissions_for_hub_as_atoms(hub)}
  end

  def room_size(hub, _args, _resolutions) do
    # No permission check needed
    {:ok, Hub.room_size_for(hub)}
  end

  def member_count(hub, _args, _resolutions) do
    # No permission check needed
    {:ok, Hub.member_count_for(hub)}
  end

  def lobby_count(hub, _args, _resolutions) do
    # No permission check needed
    {:ok, Hub.lobby_count_for(hub)}
  end

  def scene(hub, _args, _resolutions) do
    # No permission check needed
    {:ok, Hub.scene_or_scene_listing_for(hub)}
  end

  def update_room(_parent, %{id: hub_sid} = args, %{
        context: %{
          credentials: %Credentials{} = credentials
        }
      }) do
    Ret.Api.Rooms.authed_update_room(hub_sid, credentials, args)
  end

  def update_room(_parent, _args, _resolutions) do
    resolver_error(:unauthorized, "Unauthorized access")
  end
end
