defmodule Ret.Upload do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.Upload

  @schema_prefix "ret0"
  @primary_key {:upload_id, :id, autogenerate: true}

  schema "uploads" do
    field(:upload_uuid, :string)
    field(:uploader_account_id, :integer)
    # TODO BP: Use a state machine library?
    # One of "available" or "marked_for_deletion"
    field(:state, :string)
    # TODO BP: content_length is already stored in the upload's meta file.
    # Does it make sense to include it here as well?
    field(:size, :integer)

    timestamps()
  end

  def changeset(%Upload{} = upload, attrs) do
    upload
    # TODO BP: API should not accept an account_id in the request params. It should be derived from the session via
    # the auth token
    |> cast(attrs, [:uploader_account_id])
    |> validate_required([:uploader_account_id])
  end
end
