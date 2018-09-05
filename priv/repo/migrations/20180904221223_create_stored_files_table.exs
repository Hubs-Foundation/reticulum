defmodule Ret.Repo.Migrations.CreateFilesTable do
  use Ecto.Migration

  def change do
    create table(:stored_files, prefix: "ret0", primary_key: false) do
      add(:stored_file_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true)
      add(:file_sid, :string, null: false)
      add(:account_id, :bigint, null: false)
      add(:mime_type, :string, null: false)
      add(:size, :bigint, null: false)
      add(:state, :stored_file_state, null: false, default: "active")

      timestamps()
    end

    create(index(:stored_files, [:file_sid], unique: true))
    create(index(:stored_files, [:account_id]))
  end
end
