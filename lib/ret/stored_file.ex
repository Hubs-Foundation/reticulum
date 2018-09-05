defmodule Ret.StoredFile do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ret.{StoredFile, Account}

  @schema_prefix "ret0"
  @primary_key {:stored_file_id, :id, autogenerate: true}

  schema "stored_files" do
    field(:stored_file_sid, :string)
    field(:key, :string)
    field(:content_type, :string)
    field(:content_length, :integer)
    field(:state, StoredFile.State)
    belongs_to(:account, Ret.Account, references: :account_id)

    timestamps()
  end

  def changeset(struct, account, params \\ %{}) do
    struct
    |> cast(params, [:stored_file_sid, :key, :content_type, :content_length, :state])
    |> validate_required([:stored_file_sid, :key, :content_type, :content_length])
    |> unique_constraint(:stored_file_sid)
    |> put_assoc(:account, account)
  end
end
