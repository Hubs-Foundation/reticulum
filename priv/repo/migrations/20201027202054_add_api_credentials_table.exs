defmodule Ret.Repo.Migrations.AddApiCredentialsTable do
  use Ecto.Migration

  def change do
    Ret.Api.TokenSubjectType.create_type()
    Ret.Api.ScopeType.create_type()

    create table(:api_credentials, primary_key: false) do
      add(:api_credentials_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true)
      add(:token_hash, :string)
      add(:api_credentials_sid, :string)
      add(:issued_at, :utc_datetime)
      add(:expires_at, :utc_datetime)
      add(:is_revoked, :boolean)
      add(:scopes, {:array, :api_scope_type})
      add(:subject_type, :api_token_subject_type)
      add(:account_id, references(:accounts, column: :account_id))
      timestamps()
    end

    create(index(:api_credentials, [:token_hash], unique: true))
  end
end
