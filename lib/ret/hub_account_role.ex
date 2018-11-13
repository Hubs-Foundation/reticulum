defmodule Ret.HubAccountRole do
  use Ecto.Schema
  use Bitwise
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.{EncryptedField, Hub, Account, HubAccountRole, Repo}
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

  def add_host_role(%Account{} = account, %Hub{} = hub) do
    %HubAccountRole{}
    |> changeset(hub, account, %{roles: 1})
    |> Repo.insert()
  end

  def add_host_role(nil, _), do: nil

  def get_roles(%Account{} = account, %Hub{} = hub) do
    roles = Repo.get_by(HubAccountRole, hub_id: hub.hub_id, account_id: account.account_id).roles

    %{
      is_host: roles &&& 1
    }
  end

  def get_roles(nil, _), do: %{}
end
