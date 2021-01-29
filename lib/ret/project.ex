defmodule Ret.Project do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.{Repo, Project, ProjectAsset, Scene, SceneListing, OwnedFile}

  @schema_prefix "ret0"
  @primary_key {:project_id, :id, autogenerate: true}

  schema "projects" do
    field(:project_sid, :string)
    field(:name, :string)
    belongs_to(:created_by_account, Ret.Account, references: :account_id)
    belongs_to(:project_owned_file, Ret.OwnedFile, references: :owned_file_id)
    belongs_to(:thumbnail_owned_file, Ret.OwnedFile, references: :owned_file_id)

    belongs_to(:parent_scene, Scene, references: :scene_id, on_replace: :nilify)
    belongs_to(:parent_scene_listing, SceneListing, references: :scene_listing_id, on_replace: :nilify)

    many_to_many(:assets, Ret.Asset,
      join_through: Ret.ProjectAsset,
      join_keys: [project_id: :project_id, asset_id: :asset_id],
      on_replace: :delete
    )

    belongs_to(:scene, Scene, references: :scene_id, on_replace: :nilify)

    timestamps()
  end

  def to_sid(nil), do: nil
  def to_sid(%Project{} = project), do: project.project_sid
  def to_url(%Project{} = project), do: "#{RetWeb.Endpoint.url()}/projects/#{project.project_sid}"

  def project_by_sid(project_sid) do
    Project
    |> Repo.get_by(project_sid: project_sid)
    |> Repo.preload([:created_by_account, :project_owned_file, :thumbnail_owned_file, :scene])
  end

  def project_by_sid_for_account(project_sid, account) do
    from(p in Project,
      where: p.project_sid == ^project_sid and p.created_by_account_id == ^account.account_id,
      preload: [
        :created_by_account,
        :project_owned_file,
        :thumbnail_owned_file,
        scene: ^Scene.scene_preloads(),
        parent_scene: ^Scene.scene_preloads(),
        parent_scene_listing: [
          :model_owned_file,
          :screenshot_owned_file,
          :scene_owned_file,
          :project,
          :account,
          scene: ^Scene.scene_preloads()
        ],
        assets: [:asset_owned_file, :thumbnail_owned_file]
      ]
    )
    |> Repo.one()
  end

  def projects_for_account(account) do
    Repo.all(
      from(p in Project,
        where: p.created_by_account_id == ^account.account_id,
        preload: [
          :project_owned_file,
          :thumbnail_owned_file,
          scene: ^Scene.scene_preloads(),
          parent_scene: ^Scene.scene_preloads(),
          parent_scene_listing: [
            :model_owned_file,
            :screenshot_owned_file,
            :scene_owned_file,
            :project,
            :account,
            scene: ^Scene.scene_preloads()
          ]
        ],
        order_by: [desc: p.updated_at]
      )
    )
  end

  def add_asset_to_project(project, asset) do
    %ProjectAsset{} |> ProjectAsset.changeset(project, asset) |> Repo.insert()
  end

  def add_scene_to_project(%Project{} = project, scene) do
    project |> change() |> put_assoc(:scene, scene) |> Repo.update()
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
  def changeset(
        %Project{} = project,
        account,
        %OwnedFile{} = project_owned_file,
        %OwnedFile{} = thumbnail_owned_file,
        params
      ) do
    project
    |> changeset(account, params)
    |> put_assoc(:project_owned_file_id, project_owned_file)
    |> put_assoc(:thumbnail_owned_file_id, thumbnail_owned_file)
  end

  def changeset(
        %Project{} = project,
        account,
        %OwnedFile{} = project_owned_file,
        %OwnedFile{} = thumbnail_owned_file,
        nil = _parent_scene,
        params
      ) do
    project
    |> changeset(account, project_owned_file, thumbnail_owned_file, params)
  end

  def changeset(
        %Project{} = project,
        account,
        %OwnedFile{} = project_owned_file,
        %OwnedFile{} = thumbnail_owned_file,
        %Scene{} = parent_scene,
        params
      ) do
    project
    |> changeset(account, project_owned_file, thumbnail_owned_file, params)
    |> put_assoc(:parent_scene, parent_scene)
  end

  def changeset(
        %Project{} = project,
        account,
        %OwnedFile{} = project_owned_file,
        %OwnedFile{} = thumbnail_owned_file,
        %SceneListing{} = parent_scene_listing,
        params
      ) do
    project
    |> changeset(account, project_owned_file, thumbnail_owned_file, params)
    |> put_assoc(:parent_scene_listing, parent_scene_listing)
  end

  defp maybe_add_project_sid_to_changeset(changeset) do
    project_sid = changeset |> get_field(:project_sid) || Ret.Sids.generate_sid()
    put_change(changeset, :project_sid, project_sid)
  end
end
