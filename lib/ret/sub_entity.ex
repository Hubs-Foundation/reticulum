defmodule Ret.SubEntity do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.Hub
  alias Ret.{Entity, SubEntity}
  @schema_prefix "ret0"
  @primary_key {:sub_entity_id, :id, autogenerate: true}

  schema "sub_entities" do
    field :nid, :string
    field :update_message, :binary
    belongs_to :hub, Hub, references: :hub_id
    belongs_to :entity, Entity, references: :entity_id
    timestamps()
  end

  def changeset(
        %SubEntity{} = sub_entity,
        %Hub{} = hub,
        %Entity{} = entity,
        params
      ) do
    sub_entity
    |> cast(params, [:nid, :update_message])
    |> validate_required([:nid, :update_message])
    |> put_assoc(:hub, hub)
    |> put_assoc(:entity, entity)
    |> unique_constraint(:nid, name: :sub_entities_nid_hub_id_index)
  end
end
