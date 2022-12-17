defmodule Ret.Store.EntityState do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.Hub
  alias Ret.Store.EntityState
  @schema_prefix "ret0"
  @primary_key {:entity_state_id, :id, autogenerate: true}

  schema "entity_states" do
    field :root_nid, :string
    field :nid, :string
    field :message, :binary
    belongs_to :hub, Hub, references: :hub_id
    timestamps()
  end

  def changeset(%EntityState{} = entity_state, %Hub{} = hub, attrs) do
    entity_state
    |> cast(attrs, [:root_nid, :nid, :message])
    |> validate_required([:root_nid, :nid, :message])
    |> put_assoc(:hub, hub)
    |> unique_constraint(:nid, name: :entity_states_nid_hub_id_index)
    |> unique_constraint(:hub_id, name: :entity_states_hub_id_index)
  end
end
