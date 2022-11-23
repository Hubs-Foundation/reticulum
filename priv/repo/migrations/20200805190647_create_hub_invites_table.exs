defmodule Ret.Repo.Migrations.CreateHubInvitesTable do
  use Ecto.Migration

  def change do
    Ret.HubInvite.State.create_type()

    create table(:hub_invites, primary_key: false) do
      add :hub_invite_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :hub_invite_sid, :string, null: false
      add :hub_id, :bigint, null: false
      add :state, :hub_invite_state, null: false, default: "active"

      timestamps()
    end

    create unique_index(:hub_invites, [:hub_invite_sid])
  end
end
