defmodule Ret.ProjectFile do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{ProjectFile, OwnedFile}

  @schema_prefix "ret0"
  @primary_key {:project_file_id, :id, autogenerate: true}

  schema "project_files" do
    field(:project_file_sid, :string)
    field(:name, :string)
    belongs_to(:account, Ret.Account, references: :account_id)
    belongs_to(:project, Ret.Project, references: :project_id)
    belongs_to(:project_file_owned_file, Ret.OwnedFile, references: :owned_file_id)

    timestamps()
  end

  def to_sid(%ProjectFile{} = project_file), do: project_file.project_file_sid

  # Create a Project
  def changeset(%ProjectFile{} = project_file, account, project, project_file_owned_file, params) do
    project_file
    |> cast(params, [
      :name
    ])
    |> validate_required([
      :name
    ])
    |> validate_length(:name, min: 4, max: 64)
    |> maybe_add_project_file_sid_to_changeset
    |> unique_constraint(:project_file_sid)
    |> put_assoc(:account, account)
    |> put_assoc(:project, project)
    |> put_change(:project_file_owned_file_id, project_file_owned_file.owned_file_id)
  end

  defp maybe_add_project_file_sid_to_changeset(changeset) do
    project_file_sid = changeset |> get_field(:project_file_sid) || Ret.Sids.generate_sid()
    put_change(changeset, :project_file_sid, project_file_sid)
  end
end
