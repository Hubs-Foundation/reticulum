defmodule Ret.EntityState.UpdateMessage do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.Hub
  alias Ret.EntityState.{CreateMessage, UpdateMessage}
  @schema_prefix "ret0"
  @primary_key {:entity_update_message_id, :id, autogenerate: true}

  schema "entity_update_messages" do
    field :nid, :string
    field :update_message, :binary
    belongs_to :hub, Hub, references: :hub_id
    belongs_to :entity_create_message, CreateMessage, references: :entity_create_message_id
    timestamps()
  end

  def changeset(
        %UpdateMessage{} = update_message,
        %Hub{} = hub,
        %CreateMessage{} = create_message,
        params
      ) do
    update_message
    |> cast(params, [:nid, :update_message])
    |> validate_required([:nid, :update_message])
    |> put_assoc(:hub, hub)
    |> put_assoc(:entity_create_message, create_message)
    |> unique_constraint(:nid, name: :entity_update_messages_nid_hub_id_index)
  end
end
