defmodule Ret.Repo.Migrations.CreateLoginTokens do
  use Ecto.Migration

  def change do
    create table(:login_tokens, primary_key: false) do
      add :login_token_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :token, :string
      add :identifier_hash, :string

      timestamps()
    end

    create unique_index(:login_tokens, [:token])
  end
end
