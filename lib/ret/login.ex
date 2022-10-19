defmodule Ret.Login do
  use Ecto.Schema

  import Ecto.Changeset
  alias Ret.{Repo, Account, Login}

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

    login_to_update = Repo.get_by(Login, identifier_hash: old_identifier_hash)

    case login_to_update do
      %Login{} ->
        login_to_update
        |> cast(%{identifier_hash: new_identifier_hash}, [:identifier_hash])
        |> unique_constraint(:identifier_hash)
        |> Ret.Repo.update()

      nil ->
        :error
    end
  end
end
