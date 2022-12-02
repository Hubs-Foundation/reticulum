defmodule Ret.Repo.Migrations.AddProviderAccessTokens do
  use Ecto.Migration

  def change do
    alter table("oauth_providers") do
      add :provider_access_token, :binary
      add :provider_access_token_secret, :binary
    end
  end
end
