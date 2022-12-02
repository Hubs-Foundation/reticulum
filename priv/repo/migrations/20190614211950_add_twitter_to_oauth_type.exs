defmodule Ret.Repo.Migrations.AddTwitterToOauthType do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    execute "ALTER TYPE ret0.oauth_provider_source ADD VALUE IF NOT EXISTS 'twitter'"
  end
end
