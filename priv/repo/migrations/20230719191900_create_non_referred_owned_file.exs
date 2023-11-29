defmodule Ret.Repo.Migrations.CreateNonReferredOwnedFileTable do
  use Ecto.Migration

  def change do
    create table(:non_referred_owned_files, primary_key: false) do
      add :non_referred_owned_file_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :owned_file_id, :bigint, null: false
      add :owned_file_uuid, :string, null: false
      add :key, :string, null: false
      add :account_id, :bigint, null: false
      add :content_type, :string, null: false
      add :content_length, :bigint, null: false
      add :state, :owned_file_state, null: false, default: "inactive"

      timestamps()
    end

    create unique_index(:non_referred_owned_files, [:owned_file_uuid])
    create index(:non_referred_owned_files, [:account_id])
  end
end

