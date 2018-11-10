defmodule Ret.HubAccountRole do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.{EncryptedField, Hub, HubAccountRole, Repo}
  @schema_prefix "ret0"
  @primary_key {:hub_account_role_id, :id, autogenerate: true}

  schema "hub_account_roles" do
    # Bit field of roles:
    # 1 - Host
    field(:roles, :integer, default: 0)
    belongs_to(:hub, Hub, references: :hub_id)
    belongs_to(:account, Account, references: :account_id)

    timestamps()
  end

  defp changeset(%HubAccountRole{} = hub_account_role, %Hub{} = hub, %Account{} = account, attrs) do
    hub_account_role
    |> cast(attrs, [:roles])
    |> unique_constraint(:roles, name: :hub_account_roles_hub_id_account_id_index)
    |> put_assoc(:hub, hub)
    |> put_assoc(:account, account)
  end

  defp add_host_role(account, hub) when not is_nil(account) do
    %HubAccountRole{}
    |> HubAccountRole.changeset(account, hub, ${roles: 1})
    |> Repo.insert()
  end
end
