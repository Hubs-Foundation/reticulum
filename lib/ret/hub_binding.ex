defmodule Ret.HubBinding do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ret.{Hub, HubBinding, Repo}

  @schema_prefix "ret0"
  @primary_key {:hub_binding_id, :id, autogenerate: true}

  schema "hub_bindings" do
    field(:type, HubBinding.Type)
    field(:community_id, :string)
    field(:channel_id, :string)
    belongs_to(:hub, Hub, references: :hub_id)

    timestamps()
  end

  def changeset(%HubBinding{} = hub_binding, params) do
    %Hub{hub_id: hub_id} = Hub |> Repo.get_by(hub_sid: params["hub_id"])

    hub_binding
    |> cast(params, [:type, :community_id, :channel_id])
    |> put_change(:hub_id, hub_id)
  end
end
