defmodule Ret.OAuthProvider do
  use Ecto.Schema

  @schema_prefix "ret0"
  @primary_key {:oauth_provider_id, :id, autogenerate: true}

  schema "oauth_providers" do
    field :source, Ret.OAuthProvider.Source
    field :provider_account_id, :string
    field :provider_access_token, Ret.EncryptedField
    field :provider_access_token_secret, Ret.EncryptedField

    belongs_to :account, Ret.Account, references: :account_id

    timestamps()
  end
end
