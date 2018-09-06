defmodule Ret.OwnedFile do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ret.{OwnedFile, Account}

  @schema_prefix "ret0"
  @primary_key {:owned_file_id, :id, autogenerate: true}

  schema "owned_files" do
    field(:owned_file_sid, :string)
    field(:key, :string)
    field(:content_type, :string)
    field(:content_length, :integer)
    field(:state, OwnedFile.State)
    belongs_to(:account, Account, references: :account_id)

    timestamps()
  end

  def uri_for(%OwnedFile{owned_file_sid: file_sid, content_type: content_type}) do
    Ret.Storage.uri_for(file_sid, content_type)
  end

  def changeset(struct, account, params \\ %{}) do
    struct
    |> cast(params, [:owned_file_sid, :key, :content_type, :content_length, :state])
    |> validate_required([:owned_file_sid, :key, :content_type, :content_length])
    |> unique_constraint(:owned_file_sid)
    |> put_assoc(:account, account)
  end
end
