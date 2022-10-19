defmodule Ret.Login do
  use Ecto.Schema

  import Ecto.Changeset
  alias Ret.{Repo, Account}

  @schema_prefix "ret0"
  @primary_key {:login_id, :id, autogenerate: true}

  schema "logins" do
    field(:identifier_hash, :string)
    belongs_to(:account, Account, references: :account_id)

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

  def update_identifier_hash(%{old_email: old_email, new_email: new_email} = _) do
    old_identifier_hash = Account.identifier_hash_for_email(old_email)
    new_identifier_hash = Account.identifier_hash_for_email(new_email)

    login_to_update =
      Ret.Login
      |> Repo.get_by(identifier_hash: old_identifier_hash)
      |> Repo.one()

    case login_to_update do
      %Ret.Login{} ->
        login_to_update
        |> change(%{identifier_hash: new_identifier_hash})
        |> Repo.update!()

      nil ->
        :error
    end
  end
end
