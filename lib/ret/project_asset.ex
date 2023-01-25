defmodule Ret.ProjectAsset do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @schema_prefix "ret0"
  @primary_key {:project_asset_id, :id, autogenerate: true}
  schema "project_assets" do
    belongs_to :project, Ret.Project, references: :project_id
    belongs_to :asset, Ret.Asset, references: :asset_id

    timestamps()
  end

  # Create a ProjectAsset
  def changeset(project_asset, project, asset, params \\ %{}) do
    project_asset
    |> cast(params, [])
    |> put_assoc(:project, project)
    |> put_assoc(:asset, asset)
  end
end
