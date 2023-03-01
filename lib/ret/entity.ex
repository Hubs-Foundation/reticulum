defmodule Ret.Entity do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.Hub
  alias Ret.SubEntity

  @schema_prefix "ret0"
  @primary_key {:entity_id, :id, autogenerate: true}

  schema "entities" do
    field :nid, :string
    field :create_message, :binary
    belongs_to :hub, Hub, references: :hub_id
    has_many :sub_entities, SubEntity, foreign_key: :entity_id
    timestamps()
  end

  def changeset(entity, hub, params) do
    entity
    |> cast(params, [:nid, :create_message])
    |> validate_required([:nid, :create_message])
    |> put_assoc(:hub, hub)
    |> unique_constraint(:nid, name: :entities_nid_hub_id_index)
  end
end
