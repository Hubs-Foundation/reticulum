defmodule Ret.RoomObject do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.{Hub, RoomObject, Repo}
  @schema_prefix "ret0"
  @primary_key {:room_object_id, :id, autogenerate: true}

  schema "room_objects" do
    field(:room_object_sid, :string)
    field(:gltf_node, :map)

    belongs_to(:hub, Hub, references: :hub_id)

    timestamps()
  end

  def perform_pin!(%Hub{hub_id: hub_id} = hub, %{room_object_sid: room_object_sid, gltf_node: gltf_node} = attrs) do
    room_object =
      RoomObject
      |> where([t], t.hub_id == ^hub_id and t.room_object_sid == ^room_object_sid)
      |> preload(:hub)
      |> Repo.one()

    changeset(room_object || %RoomObject{}, hub, attrs) |> Repo.insert_or_update!()
  end

  def perform_unpin(%Hub{hub_id: hub_id}, room_object_sid) do
    RoomObject
    |> where([t], t.hub_id == ^hub_id and t.room_object_sid == ^room_object_sid)
    |> Repo.delete_all()
  end

  def gltf_for_hub(%Hub{hub_id: hub_id, name: hub_name}) do
    nodes =
      RoomObject
      |> where([t], t.hub_id == ^hub_id)
      |> Repo.all()
      |> Enum.map(& &1.gltf_node)

    %{
      asset: %{version: "2.0", generator: "reticulum"},
      scenes: [%{nodes: [0], name: "#{hub_name} Objects"}],
      nodes: nodes,
      extensionsUsed: ["HUBS_components"]
    }
  end

  defp changeset(%RoomObject{} = room_object, %Hub{} = hub, attrs) do
    room_object
    |> cast(attrs, [:room_object_sid, :gltf_node])
    |> unique_constraint(:room_object_sid)
    |> unique_constraint(:hub_id)
    |> put_assoc(:hub, hub)
  end
end
