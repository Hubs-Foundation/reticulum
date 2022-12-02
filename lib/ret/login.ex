defmodule Ret.Login do
  use Ecto.Schema

  import Ecto.Changeset
  alias Ret.Account

  @schema_prefix "ret0"
  @primary_key {:login_id, :id, autogenerate: true}

  schema "logins" do
    field :identifier_hash, :string

    belongs_to :account, Account, references: :account_id

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, account, params \\ %{}) do
    struct
    |> cast(params, [:identifier_hash])
    |> validate_required([:identifier_hash])
    |> unique_constraint(:identifier_hash)
    |> put_assoc(:account, account)
  end
end
