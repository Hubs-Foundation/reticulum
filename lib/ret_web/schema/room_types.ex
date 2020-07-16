defmodule RetWeb.Schema.RoomTypes do
  use Absinthe.Schema.Notation
  alias RetWeb.Resolvers

  object :room do
    field :hub_sid, :id, name: "id"
    field :name, :string
  end

  object :room_list do
    field(:total_entries, :integer)
    field(:total_pages, :integer)
    field(:page_number, :integer)
    field(:page_size, :integer)
    field(:entries, list_of(:room))
  end

  object :room_queries do
    field :list_rooms, :room_list do
      resolve(&Resolvers.RoomResolver.list_rooms/3)
    end
  end

  object :room_mutations do
    field :create_room, :room do
      arg(:name, non_null(:string))

      resolve(&Resolvers.RoomResolver.create_room/3)
    end
  end

  object :room_subscriptions do
    field :room_created, :room
  end
end