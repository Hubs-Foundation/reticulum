defmodule Ret.AccountFile do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{AccountFile, OwnedFile}

  @schema_prefix "ret0"
  @primary_key {:account_file_id, :id, autogenerate: true}

  schema "account_files" do
    field(:account_file_sid, :string)
    field(:name, :string)
    belongs_to(:account, Ret.Account, references: :account_id)
    belongs_to(:account_file_owned_file, Ret.OwnedFile, references: :owned_file_id)

    timestamps()
  end

  def to_sid(%AccountFile{} = account_file), do: account_file.account_file_sid

  # Create a Project
  def changeset(%AccountFile{} = account_file, account, account_file_owned_file, params) do
    account_file
    |> cast(params, [
      :name
    ])
    |> validate_required([
      :name
    ])
    |> validate_length(:name, min: 4, max: 64)
    |> maybe_add_account_file_sid_to_changeset
    |> unique_constraint(:account_file_sid)
    |> put_assoc(:account, account)
    |> put_change(:account_file_owned_file_id, account_file_owned_file.owned_file_id)
  end

  defp maybe_add_account_file_sid_to_changeset(changeset) do
    account_file_sid = changeset |> get_field(:account_file_sid) || Ret.Sids.generate_sid()
    put_change(changeset, :account_file_sid, account_file_sid)
  end
end
