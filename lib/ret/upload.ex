defmodule Ret.Upload do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.Upload

  @schema_prefix "ret0"
  @primary_key {:upload_id, :integer, []}

  schema "uploads" do
    # TODO BP: Should upload records really have a SID? Only adding it here since it seems to be 
    # convention in our REST APIs.
    field(:upload_sid, :string)
    field(:uploader_account_id, :integer)
    # TODO BP: Use a state machine library?
    # One of "available" or "marked_for_deletion"
    field(:state, :string)
    field(:size, :integer)

    timestamps()
  end

  def changeset(%Upload{} = upload, attrs) do
    upload
    # TODO BP: API should not accept an account_id in the request params. It should be derived from the session via
    # the auth token
    |> cast(attrs, [:uploader_account_id])
    |> validate_required([:author_account_id])
    |> add_upload_sid_to_changeset
    |> unique_constraint(:upload_sid)
  end

  defp add_upload_sid_to_changeset(changeset) do
    upload_sid = Ret.Sids.generate_sid()
    put_change(changeset, :upload_sid, "#{upload_sid}")
  end
end

