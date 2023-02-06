defmodule Ret.EntityState.CreateMessage do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.Hub
  alias Ret.EntityState.{CreateMessage, UpdateMessage}
  @schema_prefix "ret0"
  @primary_key {:entity_create_message_id, :id, autogenerate: true}

  schema "entity_create_messages" do
    field :nid, :string
    field :create_message, :binary
    belongs_to :hub, Hub, references: :hub_id
    has_many :entity_update_messages, UpdateMessage, foreign_key: :entity_create_message_id
    timestamps()
  end

  def changeset(%CreateMessage{} = create_message, %Hub{} = hub, params) do
    create_message
    |> cast(params, [:nid, :create_message])
    |> validate_required([:nid, :create_message])
    |> put_assoc(:hub, hub)
    |> unique_constraint(:nid, name: :entity_create_messages_nid_hub_id_index)
  end
end
