defmodule Ret.NonReferredOwnedFile do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ret.{OwnedFile, Account}

  @schema_prefix "ret0"
  @primary_key {:non_referred_owned_file_id, :id, autogenerate: true}
  schema "non_referred_owned_files" do
    field :owned_file_id, :integer
    field :owned_file_uuid, :string
    field :key, :string
    field :content_type, :string
    field :content_length, :integer
    field :state, OwnedFile.State

    belongs_to :account, Account, references: :account_id

    timestamps()
  end

  def changeset(struct, account, params \\ %{}) do
    struct
    |> cast(params, [:owned_file_id, :owned_file_uuid, :key, :content_type, :content_length, :state])
    |> validate_required([:owned_file_id, :owned_file_uuid, :key, :content_type, :content_length])
    |> unique_constraint(:owned_file_uuid)
    |> put_assoc(:account, account)
  end
end
