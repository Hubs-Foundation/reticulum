defmodule Ret.Project do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.{Repo, Project, OwnedFile}

  @schema_prefix "ret0"
  @primary_key {:project_id, :id, autogenerate: true}

  schema "projects" do
    field(:project_sid, :string)
    field(:name, :string)
    belongs_to(:created_by_account, Ret.Account, references: :account_id)
    belongs_to(:project_owned_file, Ret.OwnedFile, references: :owned_file_id)
    belongs_to(:thumbnail_owned_file, Ret.OwnedFile, references: :owned_file_id)
    many_to_many(:assets, Ret.Asset, join_through: Ret.ProjectAsset, join_keys: [project_id: :project_id, asset_id: :asset_id], on_replace: :delete)

    timestamps()
  end

  def to_url(%Project{} = project), do: "#{RetWeb.Endpoint.url()}/projects/#{project.project_sid}"

  def project_by_sid_for_account(account, project_sid) do
    from(p in Project,
      where: p.project_sid == ^project_sid and p.created_by_account_id == ^account.account_id,
      preload: [assets: :asset_owned_file])
    |> Repo.one
  end

  # Create a Project
  def changeset(%Project{} = project, account, params \\ %{}) do
    project
    |> cast(params, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 4, max: 64)
    # TODO BP: this is repeated from hub.ex. Maybe refactor the regex out.
    |> validate_format(:name, ~r/^[A-Za-z0-9-':"_!@#$%^&*(),.?~ ]+$/)
    |> maybe_add_project_sid_to_changeset
    |> unique_constraint(:project_sid)
    |> put_assoc(:created_by_account, account)
  end

  # Update a Project with new project and thumbnail files
  def changeset(%Project{} = project, account, %OwnedFile{} = project_owned_file, %OwnedFile{} = thumbnail_owned_file, params) do
    project
    |> changeset(account, params)
    |> put_change(:project_owned_file_id, project_owned_file.owned_file_id)
    |> put_change(:thumbnail_owned_file_id, thumbnail_owned_file.owned_file_id)
  end

  defp maybe_add_project_sid_to_changeset(changeset) do
    project_sid = changeset |> get_field(:project_sid) || Ret.Sids.generate_sid()
    put_change(changeset, :project_sid, project_sid)
  end
end
