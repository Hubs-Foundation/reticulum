defmodule Ret.Account do
  use Ecto.Schema
  import Ecto.Query

  alias Ret.{Repo, Account, Identity, Login, Guardian}

  import Canada, only: [can?: 2]

  @type id :: pos_integer
  @type t :: %__MODULE__{}

  @account_preloads [:login, :identity]

  @schema_prefix "ret0"
  @primary_key {:account_id, :id, autogenerate: true}
  schema "accounts" do
    field(:min_token_issued_at, :utc_datetime)
    field(:is_admin, :boolean)
    field(:state, Account.State)
    has_one(:login, Login, foreign_key: :account_id)
    has_one(:identity, Identity, foreign_key: :account_id)
    has_many(:owned_files, Ret.OwnedFile, foreign_key: :account_id)
    has_many(:created_hubs, Ret.Hub, foreign_key: :created_by_account_id)
    has_many(:oauth_providers, Ret.OAuthProvider, foreign_key: :account_id)
    has_many(:projects, Ret.Project, foreign_key: :created_by_account_id)
    has_many(:assets, Ret.Asset, foreign_key: :account_id)
    timestamps()
  end

  def query do
    from(account in Account)
  end

  def where_account_id_is(query, id) do
    from(account in query, where: account.account_id == ^id)
  end

  def has_accounts?(), do: from(a in Account, limit: 1) |> Repo.exists?()

  def has_admin_accounts?(),
    do: from(a in Account, limit: 1) |> where(is_admin: true) |> Repo.exists?()

  def exists_for_email?(email), do: account_for_email(email) != nil

  def account_for_email(email, create_if_not_exists \\ false) do
    email |> identifier_hash_for_email |> account_for_login_identifier_hash(create_if_not_exists)
  end

  def find_or_create_account_for_email(email), do: account_for_email(email, true)

  def account_for_login_identifier_hash(identifier_hash, create_if_not_exists \\ false) do
    login =
      Login
      |> where([t], t.identifier_hash == ^identifier_hash)
      |> Repo.one()

    cond do
      login != nil ->
        Account |> Repo.get(login.account_id) |> Repo.preload(@account_preloads)

      create_if_not_exists === true ->
        # Set the account to be an administrator if admin_email matches
        is_admin =
          with admin_email when is_binary(admin_email) <- module_config(:admin_email) do
            identifier_hash === admin_email |> identifier_hash_for_email
          else
            _ -> false
          end

        Repo.insert!(%Account{login: %Login{identifier_hash: identifier_hash}, is_admin: is_admin})

      true ->
        nil
    end
  end

  def credentials_for_account(nil), do: nil

  def credentials_for_account(account) do
    {:ok, token, _claims} = account |> Guardian.encode_and_sign()
    token
  end

  def identifier_hash_for_email(email) do
    email |> String.downcase() |> Ret.Crypto.hash()
  end

  def get_global_perms_for_account(account), do: %{} |> add_global_perms_for_account(account)

  def add_global_perms_for_account(perms, account) do
    perms
    |> Map.put(:tweet, !!oauth_provider_for_source(account, :twitter))
    |> Map.put(:create_hub, account |> can?(create_hub(nil)))
    |> maybe_add_global_admin_perms_for_account(account)
  end

  def maybe_add_global_admin_perms_for_account(perms, %Ret.Account{is_admin: true}) do
    perms
    |> Map.put(:postgrest_role, :ret_admin)
  end

  def maybe_add_global_admin_perms_for_account(perms, _account), do: perms

  def matching_oauth_providers(nil, _), do: []
  def matching_oauth_providers(_, nil), do: []

  def matching_oauth_providers(%Ret.Account{} = account, %Ret.Hub{} = hub) do
    account.oauth_providers
    |> Enum.filter(fn provider ->
      hub.hub_bindings |> Enum.any?(&(&1.type == provider.source))
    end)
  end

  def oauth_provider_for_source(%Ret.Account{} = account, oauth_provider_source)
      when is_atom(oauth_provider_source) do
    account.oauth_providers
    |> Enum.find(fn provider ->
      provider.source == oauth_provider_source
    end)
  end

  def oauth_provider_for_source(nil, _source), do: nil

  def set_identity!(%Account{} = account, name) do
    account
    |> revoke_identity!
    |> Identity.changeset_for_new(%{name: name})
    |> Repo.insert!()

    Repo.preload(account, @account_preloads, force: true)
  end

  def revoke_identity!(%Account{account_id: account_id} = account) do
    from(i in Identity, where: i.account_id == ^account_id) |> Repo.delete_all()
    Repo.preload(account, @account_preloads, force: true)
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
