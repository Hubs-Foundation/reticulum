defmodule RetWeb.Schema.RoomTypes do
  use Absinthe.Schema.Notation
  alias RetWeb.Resolvers
  alias Ret.Scene
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  object :turn_transport do
    field(:port, :integer)
  end

  object :turn_info do
    field(:credential, :string)
    field(:enabled, :boolean)
    field(:transports, list_of(:turn_transport))
    field(:username, :string)
  end

  object :member_permissions do
    field(:spawn_and_move_media, :boolean)
    field(:spawn_camera, :boolean)
    field(:spawn_drawing, :boolean)
    field(:pin_objects, :boolean)
    field(:spawn_emoji, :boolean)
    field(:fly, :boolean)
  end

  object :room do
    field(:hub_sid, :id, name: "id")
    field(:name, :string)
    field(:slug, :string)
    field(:description, :string)
    field(:allow_promotion, :boolean)
    field(:entry_code, :string)
    field(:entry_mode, :string)
    field(:host, :string)

    field(:port, :integer) do
      resolve(&Resolvers.RoomResolver.port/3)
    end

    field(:turn, :turn_info) do
      resolve(&Resolvers.RoomResolver.turn/3)
    end

    field(:embed_token, :string) do
      resolve(&Resolvers.RoomResolver.embed_token/3)
    end

    field(:member_permissions, :member_permissions) do
      resolve(&Resolvers.RoomResolver.member_permissions/3)
    end

    field(:room_size, :integer) do
      resolve(&Resolvers.RoomResolver.room_size/3)
    end

    field(:member_count, :integer) do
      resolve(&Resolvers.RoomResolver.member_count/3)
    end

    field(:lobby_count, :integer) do
      resolve(&Resolvers.RoomResolver.lobby_count/3)
    end

    field(:scene, :scene_or_scene_listing) do
      resolve(dataloader(Scene))
    end

    # TODO: Figure out user_data
  end

  object :room_list do
    field(:total_entries, :integer)
    field(:total_pages, :integer)
    field(:page_number, :integer)
    field(:page_size, :integer)
    field(:entries, list_of(:room))
  end

  object :room_queries do
    field :my_rooms, :room_list do
      arg(:page, :integer)
      arg(:page_size, :integer)
      resolve(&Resolvers.RoomResolver.my_rooms/3)
    end

    field :public_rooms, :room_list do
      arg(:page, :integer)
      arg(:page_size, :integer)
      resolve(&Resolvers.RoomResolver.public_rooms/3)
    end

    field :favorite_rooms, :room_list do
      arg(:page, :integer)
      arg(:page_size, :integer)
      resolve(&Resolvers.RoomResolver.favorite_rooms/3)
    end
  end

  object :room_mutations do
    field :create_room, :room do
      arg(:name, non_null(:string))

      resolve(&Resolvers.RoomResolver.create_room/3)
    end
    field :update_room, :room do
      arg(:id, :string)
      arg(:name, :string)
      arg(:description, :string)
      arg(:room_size, :integer)
      arg(:scene_id, :string)
      # TODO: promotion
      # TODO: add/remove owner
      # TODO: member_permissions

      resolve(&Resolvers.RoomResolver.update_room/3)
    end
  end

  object :room_subscriptions do
    field(:room_created, :room)
  end
end
