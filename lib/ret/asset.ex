defmodule Ret.Asset do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ecto.{Multi}
  alias Ret.{Repo, Asset, ProjectAsset}

  @type t :: %__MODULE__{}

  @schema_prefix "ret0"
  @primary_key {:asset_id, :id, autogenerate: true}
  schema "assets" do
    field :asset_sid, :string
    field :name, :string
    field :type, Ret.Asset.Type

    belongs_to :account, Ret.Account, references: :account_id
    belongs_to :asset_owned_file, Ret.OwnedFile, references: :owned_file_id
    belongs_to :thumbnail_owned_file, Ret.OwnedFile, references: :owned_file_id

    many_to_many :projects, Ret.Project,
      join_through: Ret.ProjectAsset,
      join_keys: [asset_id: :asset_id, project_id: :project_id],
      on_replace: :delete

    timestamps()
  end

  def create_asset(account, asset_owned_file, thumbnail_owned_file, params) do
    %Asset{}
    |> Asset.changeset(account, asset_owned_file, thumbnail_owned_file, params)
    |> Repo.insert()
  end

  def create_asset_and_project_asset(
        account,
        project,
        asset_owned_file,
        thumbnail_owned_file,
        params
      ) do
    asset_changeset =
      Asset.changeset(%Asset{}, account, asset_owned_file, thumbnail_owned_file, params)

    multi =
      Multi.new()
      |> Multi.insert(:asset, asset_changeset)
      |> Multi.run(:project_asset, fn _repo, %{asset: asset} ->
        project_asset_changeset = ProjectAsset.changeset(%ProjectAsset{}, project, asset)
        Repo.insert(project_asset_changeset)
      end)

    Repo.transaction(multi)
  end

  def asset_by_sid_for_account(asset_sid, account) do
    Repo.one(
      from a in Asset,
        where: a.asset_sid == ^asset_sid,
        where: a.account_id == ^account.account_id,
        preload: [:account, :asset_owned_file, :thumbnail_owned_file]
    )
  end

  # Create an Asset
  def changeset(%Asset{} = asset, account, asset_owned_file, thumbnail_owned_file, params) do
    asset
    |> cast(params, [:name])
    |> put_change(:type, content_type_to_asset_type!(asset_owned_file.content_type))
    |> validate_required([:name, :type])
    # Asset names are defaulted to the owned file name so allow pretty much anything
    |> validate_length(:name, min: 1, max: 256)
    |> maybe_add_asset_sid_to_changeset
    |> unique_constraint(:asset_sid)
    |> put_assoc(:account, account)
    |> put_assoc(:asset_owned_file, asset_owned_file)
    |> put_assoc(:thumbnail_owned_file, thumbnail_owned_file)
  end

  defp content_type_to_asset_type!(content_type) do
    cond do
      String.starts_with?(content_type, "video/") -> :video
      String.starts_with?(content_type, "image/") -> :image
      String.starts_with?(content_type, "model/gltf") -> :model
      String.starts_with?(content_type, "audio/") -> :audio
    end
  end

  defp maybe_add_asset_sid_to_changeset(changeset) do
    asset_sid = changeset |> get_field(:asset_sid) || Ret.Sids.generate_sid()
    put_change(changeset, :asset_sid, asset_sid)
  end
end
