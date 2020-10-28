defmodule Ret.Api.Credentials do
  @moduledoc """
  Credentials for API access.
  """
  alias Ret.Api.Credentials

  alias Ret.Account
  alias Ret.Api.Scopes

  use Ecto.Schema
  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset

  @schema_prefix "ret0"
  @primary_key {:api_credentials_id, :id, autogenerate: true}

  schema "api_credentials" do
    field(:api_credentials_sid, :string)
    field(:token_hash, :string)
    field(:subject_type, Ret.Api.TokenSubjectType)
    field(:issued_at, :utc_datetime)
    field(:expires_at, :utc_datetime)
    field(:is_revoked, :boolean)
    field(:scopes, {:array, Ret.Api.ScopeType})

    belongs_to(:account, Account, references: :account_id)
    timestamps()
  end

  def create_new_api_credentials(options) do
    %Credentials{}
    |> changeset(options)
    |> Ret.Repo.insert()
  end

  defp changeset(%Credentials{} = credentials, %{
         token_hash: token_hash,
         subject_type: subject_type,
         scopes: scopes,
         account: account
       }) do
    credentials
    |> change()
    |> add_api_credentials_sid_to_changeset
    |> add_token_hash_to_changeset(token_hash)
    |> add_subject_type_to_changeset(subject_type)
    |> add_issued_at_to_changeset(Timex.now() |> DateTime.truncate(:second))
    |> add_expires_at_to_changeset(Timex.now() |> Timex.shift(years: 1) |> DateTime.truncate(:second))
    |> add_is_revoked_to_changeset(false)
    |> add_scopes_to_changeset(scopes)
    |> add_account_id_to_changeset((account && account.account_id) || nil)
    |> unique_constraint(:api_credentials_sid)
    |> unique_constraint(:token_hash)
  end

  defp add_api_credentials_sid_to_changeset(changeset) do
    put_change(changeset, :api_credentials_sid, Ret.Sids.generate_sid())
  end

  defp add_token_hash_to_changeset(changeset, token_hash) do
    put_change(changeset, :token_hash, token_hash)
  end

  defp add_subject_type_to_changeset(changeset, subject_type) do
    put_change(changeset, :subject_type, subject_type)
  end

  defp add_issued_at_to_changeset(changeset, issued_at) do
    put_change(changeset, :issued_at, issued_at)
  end

  defp add_expires_at_to_changeset(changeset, expires_at) do
    put_change(changeset, :expires_at, expires_at)
  end

  defp add_is_revoked_to_changeset(changeset, is_revoked) do
    put_change(changeset, :is_revoked, is_revoked)
  end

  defp add_scopes_to_changeset(changeset, scopes) do
    put_change(changeset, :scopes, scopes)
  end

  defp add_account_id_to_changeset(changeset, account_id) do
    put_change(changeset, :account_id, account_id)
  end

  def query do
    from(c in Credentials, left_join: a in Account, on: c.account_id == a.account_id, preload: [account: a])
  end

  def where_sid_is(query, sid) do
    from([credential, _account] in query,
      where: credential.api_credentials_sid == ^sid
    )
  end

  def where_token_hash_is(query, hash) do
    from([credential, _account] in query,
      where: credential.token_hash == ^hash
    )
  end

  def where_account_is(query, %Account{account_id: id}) do
    from([credential, _account] in query,
      where: credential.account_id == ^id
    )
  end
end
