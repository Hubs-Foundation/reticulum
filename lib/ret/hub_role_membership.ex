defmodule Ret.HubRoleMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{HubRoleMembership}

  @schema_prefix "ret0"
  @primary_key {:hub_role_membership_id, :id, autogenerate: true}

  schema "hub_role_memberships" do
    belongs_to(:hub, Ret.Hub, references: :hub_id)
    belongs_to(:account, Ret.Account, references: :account_id)

    timestamps()
  end

  # Assign membership
  def changeset(%HubRoleMembership{} = membership, hub, account) do
    membership
    |> change()
    |> put_assoc(:hub, hub)
    |> put_assoc(:account, account)
  end
end
