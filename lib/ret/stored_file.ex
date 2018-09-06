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
    belongs_to(:account, Account, references: :account_id)

    timestamps()
  end

  def url_for(%StoredFile{stored_file_sid: file_sid, content_type: content_type}) do
    file_host = Application.get_env(:ret, Ret.StoredFiles)[:host] || RetWeb.Endpoint.url()
    ext = MIME.extensions(content_type) |> List.first()
    filename = [file_sid, ext] |> Enum.reject(&is_nil/1) |> Enum.join(".")
    "#{file_host}/files/#{filename}" |> URI.parse()
  end

  def changeset(struct, account, params \\ %{}) do
    struct
    |> cast(params, [:stored_file_sid, :key, :content_type, :content_length, :state])
    |> validate_required([:stored_file_sid, :key, :content_type, :content_length])
    |> unique_constraint(:stored_file_sid)
    |> put_assoc(:account, account)
  end
end
