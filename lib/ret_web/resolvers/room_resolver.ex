defmodule RetWeb.Resolvers.RoomResolver do
  alias Ret.Hub

  def list_rooms(_parent, _args, _resolutions) do
    {:ok, Hub.get_public_rooms(0, 10)}
  end

  def create_room(_parent, args, _resolutions) do
    Hub.create(args)
  end
end
