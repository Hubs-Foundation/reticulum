defmodule Ret.RoomObject do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.{EncryptedField, Account, Hub, RoomObject, Repo}
  @schema_prefix "ret0"
  @primary_key {:room_object_id, :id, autogenerate: true}

  schema "room_objects" do
    field(:object_id, :string)
    field(:gltf_node, EncryptedField)

    belongs_to(:hub, Hub, references: :hub_id)
    belongs_to(:account, Account, references: :account_id)

    timestamps()
  end

  def perform_pin!(%Hub{hub_id: hub_id} = hub, %Account{} = account, %{object_id: object_id} = attrs) do
    attrs = attrs |> Map.put(:gltf_node, attrs |> Map.get(:gltf_node) |> Poison.encode!())

    room_object =
      RoomObject
      |> where([t], t.hub_id == ^hub_id and t.object_id == ^object_id)
      |> preload(:hub)
      |> preload(:account)
      |> Repo.one()

    changeset(room_object || %RoomObject{}, hub, account, attrs) |> Repo.insert_or_update!()
  end

  def perform_unpin(%Hub{hub_id: hub_id}, object_id) do
    RoomObject
    |> where([t], t.hub_id == ^hub_id and t.object_id == ^object_id)
    |> Repo.delete_all()
  end

  def gltf_for_hub_id(hub_id) do
    nodes =
      RoomObject
      |> where([t], t.hub_id == ^hub_id)
      |> Repo.all()
      |> Enum.map(&(&1.gltf_node |> Poison.decode!()))

    node_indices =
      if length(nodes) == 0 do
        []
      else
        0..((nodes |> length) - 1) |> Enum.to_list()
      end

    %{
      asset: %{version: "2.0", generator: "reticulum"},
      scenes: [%{nodes: node_indices, name: "Room Objects"}],
      nodes: nodes,
      extensionsUsed: ["HUBS_components"]
    }
  end

  def rewrite_domain_for_all(old_domain_url, new_domain_url) do
    room_object_stream = from(RoomObject, select: [:room_object_id, :gltf_node]) |> Repo.stream()

    Repo.transaction(fn ->
      Enum.each(room_object_stream, fn room_object ->
        replaced_gltf_node = String.replace(room_object.gltf_node, old_domain_url, new_domain_url)
        room_object |> Ecto.Changeset.change(gltf_node: replaced_gltf_node) |> Ret.Repo.update!()
      end)

      :ok
    end)
  end

  defp changeset(%RoomObject{} = room_object, %Hub{} = hub, %Account{} = account, attrs) do
    room_object
    |> cast(attrs, [:object_id, :gltf_node])
    |> unique_constraint(:object_id, name: :room_objects_object_id_hub_id_index)
    |> unique_constraint(:hub_id, name: :room_objects_hub_id_index)
    |> put_assoc(:hub, hub)
    |> put_change(:account_id, account.account_id)
  end
end
