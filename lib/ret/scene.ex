defmodule Ret.Scene.SceneSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug

  def get_sources(_changeset, _opts) do
    [:scene_sid, :name]
  end
end

defmodule Ret.Scene do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{Repo, Scene, SceneListing, Storage}
  alias Ret.Scene.{SceneSlug}

  @schema_prefix "ret0"
  @primary_key {:scene_id, :id, autogenerate: true}

  schema "scenes" do
    field(:scene_sid, :string)
    field(:slug, SceneSlug.Type)
    field(:name, :string)
    field(:description, :string)
    field(:attribution, :string)
    field(:attributions, :map)
    field(:allow_remixing, :boolean)
    field(:allow_promotion, :boolean)
    belongs_to(:account, Ret.Account, references: :account_id)
    belongs_to(:model_owned_file, Ret.OwnedFile, references: :owned_file_id)
    belongs_to(:screenshot_owned_file, Ret.OwnedFile, references: :owned_file_id)
    belongs_to(:scene_owned_file, Ret.OwnedFile, references: :owned_file_id)
    field(:state, Scene.State)

    timestamps()
  end

  def scene_or_scene_listing_by_sid(sid) do
    Scene |> Repo.get_by(scene_sid: sid) || SceneListing |> Repo.get_by(scene_listing_sid: sid) |> Repo.preload(:scene)
  end

  def to_sid(%Scene{} = scene), do: scene.scene_sid
  def to_sid(%SceneListing{} = scene_listing), do: scene_listing.scene_listing_sid
  def to_url(%t{} = s) when t in [Scene, SceneListing], do: "#{RetWeb.Endpoint.url()}/scenes/#{s |> to_sid}/#{s.slug}"

  def changeset(
        %Scene{} = scene,
        account,
        model_owned_file,
        screenshot_owned_file,
        scene_owned_file,
        params \\ %{}
      ) do
    scene
    |> cast(params, [
      :name,
      :description,
      :attribution,
      :attributions,
      :allow_remixing,
      :allow_promotion,
      :state
    ])
    |> validate_required([
      :name
    ])
    |> validate_length(:name, min: 4, max: 64)
    # TODO BP: this is repeated from hub.ex. Maybe refactor the regex out.
    |> validate_format(:name, ~r/^[A-Za-z0-9-':"!@#$%^&*(),.?~ ]+$/)
    |> maybe_add_scene_sid_to_changeset
    |> unique_constraint(:scene_sid)
    |> put_assoc(:account, account)
    |> put_change(:model_owned_file_id, model_owned_file.owned_file_id)
    |> put_change(:screenshot_owned_file_id, screenshot_owned_file.owned_file_id)
    |> put_change(:scene_owned_file_id, scene_owned_file.owned_file_id)
    |> SceneSlug.maybe_generate_slug()
    |> SceneSlug.unique_constraint()
  end

  def changeset_to_mark_as_reviewed(%Scene{} = scene) do
    scene
    |> Ecto.Changeset.change()
    |> put_change(:reviewed_at, Timex.now())
  end

  defp maybe_add_scene_sid_to_changeset(changeset) do
    scene_sid = changeset |> get_field(:scene_sid) || Ret.Sids.generate_sid()
    put_change(changeset, :scene_sid, scene_sid)
  end

  def static_controlled_media_for_scene(nil) do
    []
  end

  def networked_objects_for_scene(%Scene{model_owned_file: model_owned_file}) do
    case Storage.fetch(model_owned_file) do
      {:ok, _meta, stream} ->
        json =
          stream
          |> Enum.join("")

        IO.inspect(["BPDEBUG json", json])

        networked_objects =
          json
          |> Poison.decode!()
          |> Map.get("nodes")
          |> Enum.filter(fn node ->
            node["extras"]["gltfExtensions"]["MOZ_hubs_components"]["networked"]["id"] != nil
          end)
          |> Enum.map(fn node ->
            node["extras"]["gltfExtensions"]["MOZ_hubs_components"]
          end)

        IO.inspect(["BPDEBUG networked_objects", networked_objects])
        networked_objects

      {:error, _} ->
        []
    end
  end
end
