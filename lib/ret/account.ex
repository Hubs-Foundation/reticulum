defmodule Ret.Account do
  use Ecto.Schema
  import Ecto.Changeset

  @schema_prefix "ret0"
  @primary_key {:account_id, :integer, []}

  schema "accounts" do
    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [])
    |> validate_required([])
  end
end
