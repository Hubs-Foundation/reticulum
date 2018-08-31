defmodule Ret.Repo.Migrations.CreateLoginTokens do
  use Ecto.Migration

  def change do
    create table(:login_tokens, prefix: "ret0", primary_key: false) do
      add(:login_token_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true)
      add(:token, :string)
      add(:email, :string)

      timestamps()
    end

    create(index(:login_tokens, [:token], unique: true))
  end
end
