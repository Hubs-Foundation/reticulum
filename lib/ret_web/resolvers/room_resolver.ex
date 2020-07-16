defmodule RetWeb.Resolvers.RoomResolver do
  alias Ret.Hub
  import Canada, only: [can?: 2]

  def my_rooms(_parent, args, %{context: %{account: account} }) do
    {:ok, Hub.get_my_rooms(account, args)}
  end

  def my_rooms(_parent, args, _resolutions) do
    {:error, "Not authorized"}
  end

  def favorite_rooms(_parent, args, %{context: %{account: account} }) do
    {:ok, Hub.get_favorite_rooms(account, args)}
  end

  def favorite_rooms(_parent, args, _resolutions) do
    {:error, "Not authorized"}
  end

  def public_rooms(_parent, args, _resolutions) do
    {:ok, Hub.get_public_rooms(args)}
  end

  def create_room(_parent, args, _resolutions) do
    Hub.create(args)
  end

  def embed_token(hub, _args, %{context: %{account: account} }) do
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
end
