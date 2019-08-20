defmodule Ret.SceneListing.SceneListingSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug, always_change: true

  def get_sources(_changeset, _opts) do
    [:scene_listing_sid, :name]
  end
end

defmodule Ret.SceneListing do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{SceneListing}
  alias Ret.SceneListing.{SceneListingSlug}

  @schema_prefix "ret0"
  @primary_key {:scene_listing_id, :id, autogenerate: true}

  schema "scene_listings" do
    field(:scene_listing_sid, :string)
    field(:slug, SceneListingSlug.Type)
    field(:name, :string)
    field(:description, :string)
    field(:tags, :map)
    field(:attributions, :map)
    belongs_to(:scene, Ret.Scene, references: :scene_id)
    belongs_to(:model_owned_file, Ret.OwnedFile, references: :owned_file_id)
    belongs_to(:screenshot_owned_file, Ret.OwnedFile, references: :owned_file_id)
    belongs_to(:scene_owned_file, Ret.OwnedFile, references: :owned_file_id)
    has_one(:account, through: [:scene, :account])
    field(:order, :integer)
    field(:state, SceneListing.State)

    timestamps()
  end

  def changeset_for_listing_for_scene(
        %SceneListing{} = listing,
        scene,
        params \\ %{}
      ) do
    listing
    |> cast(params, [:name, :description, :order, :tags])
    |> maybe_add_scene_listing_sid_to_changeset
    |> unique_constraint(:scene_listing_sid)
    |> put_assoc(:scene, scene)
    |> put_change(:name, params[:name] || scene.name)
    |> put_change(:description, params[:description] || scene.description)
    |> put_change(:attributions, scene.attributions)
    |> put_change(:model_owned_file_id, scene.model_owned_file.owned_file_id)
    |> put_change(:screenshot_owned_file_id, scene.screenshot_owned_file.owned_file_id)
    |> put_change(:scene_owned_file_id, scene.scene_owned_file.owned_file_id)
    |> SceneListingSlug.maybe_generate_slug()
  end

  defp maybe_add_scene_listing_sid_to_changeset(changeset) do
    scene_listing_sid = changeset |> get_field(:scene_listing_sid) || Ret.Sids.generate_sid()
    put_change(changeset, :scene_listing_sid, "#{scene_listing_sid}")
  end
end
