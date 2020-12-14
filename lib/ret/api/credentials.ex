defmodule Ret.Api.Credentials do
  @moduledoc """
  Credentials for API access.
  """
  alias Ret.Api.Credentials

  alias Ret.Account

  use Ecto.Schema
  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset
  alias Ret.Api.{TokenSubjectType, ScopeType}

  @schema_prefix "ret0"
  @primary_key {:api_credentials_id, :id, autogenerate: true}

  schema "api_credentials" do
    field(:api_credentials_sid, :string)
    field(:token_hash, :string)
    field(:subject_type, TokenSubjectType)
    field(:issued_at, :utc_datetime)
    field(:is_revoked, :boolean)
    field(:scopes, {:array, ScopeType})

    belongs_to(:account, Account, references: :account_id)
    timestamps()
  end

  @required_keys [:api_credentials_sid, :token_hash, :subject_type, :issued_at, :is_revoked, :scopes]
  @permitted_keys @required_keys

  def generate_credentials(%{subject_type: _st, scopes: _sc, account_or_nil: account_or_nil} = params) do
    sid = Ret.Sids.generate_sid()

    # Use 18 bytes (not 16, the default) to avoid having all tokens end in "09"
    # See https://github.com/patricksrobertson/secure_random.ex/issues/11
    # Prefix the sid to the rest of the token for ease of management
    token = "#{sid}.#{SecureRandom.urlsafe_base64(18)}"

    params =
      Map.merge(params, %{
        api_credentials_sid: sid,
        token_hash: Ret.Crypto.hash(token),
        issued_at: Timex.now() |> DateTime.truncate(:second),
        is_revoked: false
      })

    case %Credentials{}
         |> change()
         |> cast(params, @permitted_keys)
         |> maybe_put_assoc_account(account_or_nil)
         |> validate_required(@required_keys)
         |> validate_change(:subject_type, &validate_subject_type/2)
         |> validate_change(:scopes, &validate_scopes_type/2)
         |> unique_constraint(:api_credentials_sid)
         |> unique_constraint(:token_hash)
         # TODO: We can pass multiple fields to unique_contraint when we update ecto
         # https://github.com/elixir-ecto/ecto/pull/3276
         |> Ret.Repo.insert() do
      {:ok, credentials} ->
        {:ok, token, credentials}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_put_assoc_account(changeset, %Account{} = account) do
    put_assoc(changeset, :account, account)
  end

  defp maybe_put_assoc_account(changeset, nil) do
    changeset
  end

  defp validate_scopes_type(:scopes, scopes) do
    Enum.reduce(scopes, [], fn scope, errors ->
      errors ++ validate_single_scope_type(scope)
    end)
  end

  defp validate_single_scope_type(scope) do
    if ScopeType.valid_value?(scope) do
      []
    else
      [invalid_scope: "Unrecognized scope type. Got #{scope}."]
    end
  end

  defp validate_subject_type(:subject_type, subject_type) do
    if TokenSubjectType.valid_value?(subject_type) do
      []
    else
      [subject_type: "Unrecognized subject type. Must be app or account. Got #{subject_type}."]
    end
  end

  def revoke(credentials) do
    credentials
    |> change()
    |> put_change(:is_revoked, true)
    |> Ret.Repo.update()
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
