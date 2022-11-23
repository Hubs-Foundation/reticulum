defmodule Ret.Repo.Migrations.CreateAvatars do
  use Ecto.Migration

  def change do
    create table(:avatars, primary_key: false) do
      add :avatar_id, :bigint, default: fragment("ret0.next_id()"), primary_key: true
      add :avatar_sid, :string
      add :slug, :string, null: false
      add :parent_avatar_id, references(:avatars, column: :avatar_id)
      add :name, :string
      add :description, :string
      add :attributions, :jsonb
      add :allow_remixing, :boolean, null: false, default: false
      add :allow_promotion, :boolean, null: false, default: false
      add :account_id, references(:accounts, column: :account_id), null: false
      add :gltf_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :bin_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :base_map_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :emissive_map_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :normal_map_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :orm_map_owned_file_id, references(:owned_files, column: :owned_file_id)
      add :state, :scene_state, null: false, default: "active"

      timestamps()
    end

    create constraint(:avatars, :gltf_or_parent,
             check:
               "parent_avatar_id is not null or (gltf_owned_file_id is not null and bin_owned_file_id is not null)"
           )

    create unique_index(:avatars, [:avatar_sid])
    create index(:avatars, [:account_id])
  end
end
