defmodule Ret.Scene.SceneSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug, always_change: true

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

    field(:imported_from_host, :string)
    field(:imported_from_port, :integer)
    field(:imported_from_sid, :string)

    belongs_to(:account, Ret.Account, references: :account_id)
    belongs_to(:model_owned_file, Ret.OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:screenshot_owned_file, Ret.OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:scene_owned_file, Ret.OwnedFile, references: :owned_file_id, on_replace: :nilify)
    field(:state, Scene.State)

    timestamps()
  end

  def scene_or_scene_listing_by_sid(sid) do
    Scene |> Repo.get_by(scene_sid: sid) || SceneListing |> Repo.get_by(scene_listing_sid: sid) |> Repo.preload(:scene)
  end

  def to_sid(%Scene{} = scene), do: scene.scene_sid
  def to_sid(%SceneListing{} = scene_listing), do: scene_listing.scene_listing_sid
  def to_url(%t{} = s) when t in [Scene, SceneListing], do: "#{RetWeb.Endpoint.url()}/scenes/#{s |> to_sid}/#{s.slug}"

  defp fetch_remote_scene!(uri) do
    %{body: body} = HTTPoison.get!(uri)
    body |> Poison.decode!() |> get_in(["scenes", Access.at(0)])
  end

  def import_from_url!(uri, account) do
    remote_scene = uri |> fetch_remote_scene!()
    [imported_from_host, imported_from_port] = [:host, :port] |> Enum.map(&(uri |> URI.parse() |> Map.get(&1)))
    imported_from_sid = remote_scene["scene_id"]

    [model_owned_file, screenshot_owned_file] =
      [remote_scene["model_url"], remote_scene["screenshot_url"]] |> Storage.owned_files_from_urls!(account)

    scene =
      Scene
      |> Repo.get_by(
        imported_from_host: imported_from_host,
        imported_from_port: imported_from_port,
        imported_from_sid: imported_from_sid
      )
      |> Repo.preload([:account, :model_owned_file, :screenshot_owned_file, :scene_owned_file])

    # Disallow non-admins from importing if account varies
    if scene && scene.account_id != account.account_id && !account.is_admin do
      raise "Cannot import existing scene, owned by another account."
    end

    {:ok, new_scene} =
      (scene || %Scene{})
      |> Scene.changeset(account, model_owned_file, screenshot_owned_file, nil, %{
        name: remote_scene["name"],
        description: remote_scene["description"],
        attributions: remote_scene["attribution"],
        allow_remixing: remote_scene["allow_remixing"],
        imported_from_host: imported_from_host,
        imported_from_port: imported_from_port,
        imported_from_sid: imported_from_sid,
        allow_promotion: true
      })
      |> Repo.insert_or_update()

    new_scene
  end

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
      :imported_from_host,
      :imported_from_port,
      :imported_from_sid,
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
    |> put_assoc(:model_owned_file, model_owned_file)
    |> put_assoc(:screenshot_owned_file, screenshot_owned_file)
    |> put_assoc(:scene_owned_file, scene_owned_file)
    |> SceneSlug.maybe_generate_slug()
  end

  def changeset_to_mark_as_reviewed(%Scene{} = scene) do
    scene
    |> Ecto.Changeset.change()
    |> put_change(:reviewed_at, Timex.now() |> DateTime.truncate(:second))
  end

  defp maybe_add_scene_sid_to_changeset(changeset) do
    scene_sid = changeset |> get_field(:scene_sid) || Ret.Sids.generate_sid()
    put_change(changeset, :scene_sid, scene_sid)
  end
end
