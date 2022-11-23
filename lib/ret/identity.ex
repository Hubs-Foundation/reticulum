defmodule Ret.Identity do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.Identity

  @schema_prefix "ret0"
  @primary_key {:identity_id, :id, autogenerate: true}

  schema "identities" do
    field :name, :string

    belongs_to :account, Ret.Account, references: :account_id

    timestamps()
  end

  def changeset_for_new(account, params \\ %{}) do
    %Identity{}
    |> cast(params, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 64)
    |> put_assoc(:account, account)
  end
end
