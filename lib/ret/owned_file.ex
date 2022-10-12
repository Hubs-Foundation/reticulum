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

  def url_or_nil_for(%Ret.OwnedFile{} = f), do: f |> OwnedFile.uri_for() |> URI.to_string()
  def url_or_nil_for(_), do: nil

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

  def inactive() do
    OwnedFile
    |> where(state: "inactive")
    |> Repo.all()
  end

  def set_active(owned_file_uuid, account_id) do
    get_by_uuid_and_account(owned_file_uuid, account_id) |> set_state(:active)
  end

  def set_inactive(owned_file_uuid, account_id) do
    get_by_uuid_and_account(owned_file_uuid, account_id) |> set_state(:inactive)
  end

  def set_inactive(%OwnedFile{} = owned_file) do
    set_state(owned_file, :inactive)
  end

  def get_by_uuid_and_account(owned_file_uuid, account_id) do
    OwnedFile
    |> where(owned_file_uuid: ^owned_file_uuid, account_id: ^account_id)
    |> Repo.one()
  end

  defp set_state(nil, _state), do: nil

  defp set_state(%OwnedFile{} = owned_file, state) do
    owned_file
    |> change(%{state: state})
    |> Repo.update()
  end
end
