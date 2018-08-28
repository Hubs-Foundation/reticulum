defmodule Ret.Repo.Migrations.CreateUploadsTable do
  use Ecto.Migration

  def change do
    create table(:uploads, prefix: "ret0", primary_key: false) do
      add :upload_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :upload_uuid, :string
      add :uploader_account_id, :integer, null: false
      # TODO BP: These should probably be non-null
      add :state, :string
      add :size, :bigint

      timestamps()
    end

    create index(:uploads, [:upload_uuid], unique: true)
  end
end
