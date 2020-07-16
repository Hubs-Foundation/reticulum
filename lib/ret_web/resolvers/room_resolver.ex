defmodule RetWeb.Resolvers.RoomResolver do
  alias Ret.Hub

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
end
