defmodule Ret.OwnedFile do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  alias Ret.{Repo, OwnedFile, Account}

  @schema_prefix "ret0"
  @primary_key {:owned_file_id, :id, autogenerate: true}

  schema "owned_files" do
    field(:owned_file_uuid, :string)
    field(:key, :string)
    field(:content_type, :string)
    field(:content_length, :integer)
    field(:state, OwnedFile.State)
    belongs_to(:account, Account, references: :account_id)

    timestamps()
  end

  def uri_for(%OwnedFile{owned_file_uuid: file_uuid, content_type: content_type}) do
    Ret.Storage.uri_for(file_uuid, content_type)
  end

  def changeset(struct, account, params \\ %{}) do
    struct
    |> cast(params, [:owned_file_uuid, :key, :content_type, :content_length, :state])
    |> validate_required([:owned_file_uuid, :key, :content_type, :content_length])
    |> unique_constraint(:owned_file_uuid)
    |> put_assoc(:account, account)
  end

  def set_inactive(owned_file_uuid, account_id) do
    OwnedFile
    |> where(owned_file_uuid: ^owned_file_uuid, account_id: ^account_id)
    |> Repo.one()
    |> set_inactive
  end

  def set_inactive(nil), do: nil

  def set_inactive(%OwnedFile{} = owned_file) do
    owned_file
    |> change(%{state: :inactive})
    |> Repo.update()
  end
end
