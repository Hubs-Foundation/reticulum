defmodule Ret.Login do
  use Ecto.Schema
  import Ecto.Changeset

  @schema_prefix "ret0"
  @primary_key {:login_id, :integer, []}

  schema "logins" do
    field(:email, :string)
    belongs_to(:account, Ret.Account, references: :account_id)

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, account, params \\ %{}) do
    struct
    |> cast(params, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
    |> put_assoc(:account, account)
  end
end
