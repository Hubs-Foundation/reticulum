defmodule Ret.Repo.Migrations.CreateProjectFilesTable do
  use Ecto.Migration

  def change do
    create table(:project_files, prefix: "ret0", primary_key: false) do
      add(:project_file_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true)
      add(:project_file_sid, :string)
      add(:name, :string, null: false)
      add(:account_id, references(:accounts, column: :account_id), null: false)
      add(:project_id, references(:projects, column: :project_id), null: false)
      add(:project_file_owned_file_id, :bigint, null: false)

      timestamps()
    end

    create(index(:project_files, [:project_file_sid], unique: true))
    create(index(:project_files, [:account_id]))
    create(index(:project_files, [:project_id]))

    create table(:account_files, prefix: "ret0", primary_key: false) do
      add(:account_file_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true)
      add(:account_file_sid, :string)
      add(:name, :string, null: false)
      add(:account_id, references(:accounts, column: :account_id), null: false)
      add(:account_file_owned_file_id, :bigint, null: false)

      timestamps()
    end

    create(index(:account_files, [:account_file_sid], unique: true))
    create(index(:account_files, [:account_id]))
  end
end
