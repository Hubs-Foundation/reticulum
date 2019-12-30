defmodule Ret.Repo.Migrations.AddTwitterToOauthType do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    Ecto.Migration.execute("ALTER TYPE oauth_provider_source ADD VALUE IF NOT EXISTS 'twitter'")
  end
end
