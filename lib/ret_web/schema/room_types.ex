defmodule RetWeb.Schema.RoomTypes do
  @moduledoc "GraphQL Schema"

  use Absinthe.Schema.Notation
  alias RetWeb.Resolvers

  import_types RetWeb.Schema.Types.Custom.JSON

  @desc "Public TLS port number used for TURN"
  object :turn_transport do
    @desc "Public TLS port number used for TURN"
    field :port, :integer
  end

  @desc "TURN information for DLTS over TURN fallback, when enabled"
  object :turn_info do
    @desc "Cryptographic credential, good for two minutes"
    field :credential, :string
    @desc "Whether TURN is enabled/configured"
    field :enabled, :boolean
    @desc "List of public TLS ports"
    field :transports, list_of(:turn_transport)
    @desc "Username, good for two minutes"
    field :username, :string
  end

  @desc "Permissions for participants in the room"
  input_object :input_member_permissions do
    @desc "Allows non-admin participants to spawn and move media"
    field :spawn_and_move_media, :boolean
    @desc "Allows non-admin participants to spawn in-game cameras"
    field :spawn_camera, :boolean
    @desc "Allows non-admin participants to draw with a pen"
    field :spawn_drawing, :boolean
    @desc "Allows non-admin participants to pin media to the room"
    field :pin_objects, :boolean
    @desc "Allows non-admin participants to spawn emoji"
    field :spawn_emoji, :boolean
    @desc "Allows non-admin participants to toggle fly mode"
    field :fly, :boolean
    @desc "Allows non-admin participants to use the voice chat"
    field :voice_chat, :boolean
    @desc "Allows non-admin participants to use the text chat"
    field :text_chat, :boolean
  end

  @desc "Permissions for participants in the room"
  object :member_permissions do
    @desc "Allows non-admin participants to spawn and move media"
    field :spawn_and_move_media, :boolean
    @desc "Allows non-admin participants to spawn in-game cameras"
    field :spawn_camera, :boolean
    @desc "Allows non-admin participants to draw with a pen"
    field :spawn_drawing, :boolean
    @desc "Allows non-admin participants to pin media to the room"
    field :pin_objects, :boolean
    @desc "Allows non-admin participants to spawn emoji"
    field :spawn_emoji, :boolean
    @desc "Allows non-admin participants to toggle fly mode"
    field :fly, :boolean
    @desc "Allows non-admin participants to use the voice chat"
    field :voice_chat, :boolean
    @desc "Allows non-admin participants to use the text chat"
    field :text_chat, :boolean
  end

  @desc "A room"
  object :room do
    @desc "The room's unique ID"
    field :hub_sid, :id, name: "id"
    @desc "The room's name"
    field :name, :string
    @desc "The room's name as it appears at the end of its URL"
    field :slug, :string
    @desc "A description of the room"
    field :description, :string
    @desc "Makes this room as public (while it is still open)"
    field :allow_promotion, :boolean

    @desc "Temporary entry code"
    field :entry_code, :string do
      deprecate "Entry codes have been removed."
      resolve &Resolvers.RoomResolver.entry_code/3
    end

    @desc "Determines if entry is allowed, denied, or by-invite-only. (Values are \"allow\", \"deny\", or \"invite\".)"
    field :entry_mode, :string
    @desc "The host server associated with this room via the load balancer"
    field :host, :string

    @desc "The port number used to connect to the host server"
    field :port, :integer do
      @desc "The port number used to connect to the host server"
      resolve &Resolvers.RoomResolver.port/3
    end

    @desc "TURN information for DLTS over TURN fallback, when enabled"
    field :turn, :turn_info do
      resolve &Resolvers.RoomResolver.turn/3
    end

    @desc """
    Can be used to remove the X-Frame-Options header that is usually served to the Hubs client when this room is loaded, so that the client can access this room from a <frame>, <iframe>, <embed> or <object>.
    """
    field :embed_token, :string do
      resolve &Resolvers.RoomResolver.embed_token/3
    end

    @desc """
    Can be used to assign the room creator. (It will be blank if the room creator is already assigned.)
    """
    field :creator_assignment_token, :string

    @desc "Permissions for participants in the room"
    field :member_permissions, :member_permissions do
      resolve &Resolvers.RoomResolver.member_permissions/3
    end

    @desc "Number of participants allowed to enter the room"
    field :room_size, :integer do
      resolve &Resolvers.RoomResolver.room_size/3
    end

    @desc "Number of participants in the room as avatars"
    field :member_count, :integer do
      resolve &Resolvers.RoomResolver.member_count/3
    end

    @desc "Number of participants in the room lobby"
    field :lobby_count, :integer do
      resolve &Resolvers.RoomResolver.lobby_count/3
    end

    @desc "Scene currently associated with the room"
    field :scene, :scene_or_scene_listing do
      resolve &Resolvers.RoomResolver.scene/3
    end

    @desc "Default environment gltf bundle url associated with the room (instead of a scene or scene listing)"
    field :default_environment_gltf_bundle_url, :string

    @desc "Arbitrary json data associated with the room"
    field :user_data, :json
  end

  @desc """
  A list of rooms, with metadata for paging
  """
  object :room_list do
    @desc "Total number of rooms for the given query"
    field :total_entries, :integer
    @desc "Total number of pages for the given query"
    field :total_pages, :integer
    @desc "Page number returned for this query"
    field :page_number, :integer
    @desc "Number of rooms per page"
    field :page_size, :integer
    @desc "The list of rooms"
    field :entries, list_of(:room)
  end

  @desc """
  Queries designed to return lists of rooms
  """
  object :room_queries do
    @desc """
    Returns a list of rooms created by the given user, identified by the authorization token.
    """
    field :my_rooms, :room_list do
      @desc "The desired page of data to return"
      arg :page, :integer
      @desc "The number of entries per page"
      arg :page_size, :integer
      resolve &Resolvers.RoomResolver.my_rooms/3
    end

    @desc """
    Returns a list of public rooms.
    """
    field :public_rooms, :room_list do
      @desc "The desired page of data to return"
      arg :page, :integer
      @desc "The number of entries per page"
      arg :page_size, :integer
      resolve &Resolvers.RoomResolver.public_rooms/3
    end

    @desc """
    Returns a list of rooms favorited by the given user, identified by the authorization token.
    """
    field :favorite_rooms, :room_list do
      @desc "The desired page of data to return"
      arg :page, :integer
      @desc "The number of entries per page"
      arg :page_size, :integer
      resolve &Resolvers.RoomResolver.favorite_rooms/3
    end
  end

  @desc "Entry point for mutating the database"
  object :room_mutations do
    @desc "Create a room with the given properties"
    field :create_room, :room do
      @desc "The room name"
      arg :name, :string
      @desc "A description of the room"
      arg :description, :string
      @desc "The number of participants allowed into the room from the lobby at any given time"
      arg :room_size, :integer
      @desc "The id of the scene to associate with the room"
      arg :scene_id, :string
      @desc "The url of the scene to associate with the room"
      arg :scene_url, :string
      @desc "The permissions non-admin participants should have in the room"
      arg :member_permissions, :input_member_permissions
      @desc "Arbitrary json data associated with this room"
      arg :user_data, :json

      resolve &Resolvers.RoomResolver.create_room/3
    end

    @desc "Update properties of the room specified by the given id"
    field :update_room, :room do
      @desc "The id of the room to update"
      arg :id, non_null(:string)
      @desc "The room name"
      arg :name, :string
      @desc "A description of the room"
      arg :description, :string
      @desc "The number of participants allowed into the room from the lobby at any given time"
      arg :room_size, :integer
      @desc "The id of the scene to associate with the room"
      arg :scene_id, :string
      @desc "The url of the scene to associate with the room"
      arg :scene_url, :string
      @desc "The permissions non-admin participants should have in the room"
      arg :member_permissions, :input_member_permissions
      @desc "Arbitrary json data associated with this room"
      arg :user_data, :json

      # TODO: add/remove owner

      resolve &Resolvers.RoomResolver.update_room/3
    end
  end

  object :room_subscriptions do
    field :room_created, :room
  end
end
