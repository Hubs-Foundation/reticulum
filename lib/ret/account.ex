defmodule Ret.Account do
  use Ecto.Schema
  import Ecto.Query

  alias Ret.{Repo, Account, Login, Guardian}

  @schema_prefix "ret0"
  @primary_key {:account_id, :id, autogenerate: true}

  schema "accounts" do
    field(:min_token_issued_at, :utc_datetime)
    field(:is_admin, :boolean)
    has_one(:login, Ret.Login, foreign_key: :account_id)
    has_many(:owned_files, Ret.OwnedFile, foreign_key: :account_id)
    has_many(:created_hubs, Ret.Hub, foreign_key: :created_by_account_id)
    has_many(:oauth_providers, Ret.OAuthProvider, foreign_key: :account_id)
    has_many(:projects, Ret.Project, foreign_key: :created_by_account_id)
    has_many(:assets, Ret.Asset, foreign_key: :account_id)
    timestamps()
  end

  def has_accounts?(), do: from(a in Account, limit: 1) |> Repo.exists?()
  def has_admin_accounts?(), do: from(a in Account, limit: 1) |> where(is_admin: true) |> Repo.exists?()

  def account_for_email(email) do
    email |> identifier_hash_for_email |> account_for_identifier_hash
  end

  def account_for_identifier_hash(identifier_hash) do
    login =
      Login
      |> where([t], t.identifier_hash == ^identifier_hash)
      |> Repo.one()

    if login do
      Account |> Repo.get(login.account_id) |> Repo.preload(:login)
    else
      # Set the account to be an administrator if admin_email matches
      is_admin = with admin_email when is_binary(admin_email) <- module_config(:admin_email) do
        identifier_hash === admin_email |> identifier_hash_for_email
      else
        false
      end

      Repo.insert!(%Account{login: %Login{identifier_hash: identifier_hash}, is_admin: is_admin})
    end
  end

  def credentials_for_identifier_hash(identifier_hash) do
    identifier_hash
    |> account_for_identifier_hash
    |> credentials_for_account
  end

  def credentials_for_account(account) do
    {:ok, token, _claims} = account |> Guardian.encode_and_sign()
    token
  end

  def identifier_hash_for_email(email) do
    email |> String.downcase() |> Ret.Crypto.hash()
  end

  def add_global_perms_for_account(perms, %Ret.Account{is_admin: true} = account) do
    perms
    |> Map.put(:postgrest_role, :ret_admin)
    |> Map.put(:tweet, !!oauth_provider_for_source(account, :twitter))
  end

  def add_global_perms_for_account(perms, account) do
    perms |> Map.put(:tweet, !!oauth_provider_for_source(account, :twitter))
  end

  def matching_oauth_providers(nil, _), do: []
  def matching_oauth_providers(_, nil), do: []

  def matching_oauth_providers(%Ret.Account{} = account, %Ret.Hub{} = hub) do
    account.oauth_providers
    |> Enum.filter(fn provider ->
      hub.hub_bindings |> Enum.any?(&(&1.type == provider.source))
    end)
  end

  def oauth_provider_for_source(%Ret.Account{} = account, oauth_provider_source) when is_atom(oauth_provider_source) do
    account.oauth_providers
    |> Enum.find(fn provider ->
      provider.source == oauth_provider_source
    end)
  end

  def oauth_provider_for_source(nil, _source), do: nil

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
