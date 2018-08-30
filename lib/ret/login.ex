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
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:email])
    |> validate_required([:email])
  end
end
