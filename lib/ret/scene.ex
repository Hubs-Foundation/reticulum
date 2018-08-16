defmodule Ret.Scene.SceneSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug

  def get_sources(_changeset, _opts) do
    [:scene_sid, :name]
  end
end

defmodule Ret.Scene do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.Scene
  alias Ret.Scene.{SceneSlug}

  use Bitwise

  @schema_prefix "ret0"
  @primary_key {:scene_id, :integer, []}
  @num_random_bits_for_scene_sid 16

  schema "scenes" do
    field(:scene_sid, :string)
    field(:slug, SceneSlug.Type)
    field(:name, :string)
    field(:description, :string)
    field(:author_account_id, :integer)
    field(:upload_id, :integer)
    field(:attribution_name, :string)
    field(:attribution_link, :string)
    field(:derived_from_scene_id, :integer)

    timestamps()
  end

  def changeset(%Scene{} = scene, attrs) do
    scene
    |> cast(attrs, [:name, :description, :attribution_name, :attribution_link, :author_account_id, :upload_id])
    |> validate_required([:name, :attribution_name, :author_account_id, :upload_id])
    |> validate_length(:name, min: 4, max: 64)
    |> validate_format(:name, ~r/^[A-Za-z0-9-':"!@#$%^&*(),.?~ ]+$/)
    |> add_scene_sid_to_changeset
    |> unique_constraint(:scene_sid)
    |> SceneSlug.maybe_generate_slug()
    |> SceneSlug.unique_constraint()
  end

  # TODO: BP this is repeated from hub.ex. Refactor it out.
  defp add_scene_sid_to_changeset(changeset) do
    scene_sid =
      @num_random_bits_for_scene_sid
      |> :crypto.strong_rand_bytes()
      |> Base.encode32()
      |> String.downcase()
      |> String.slice(0, 10)

    Ecto.Changeset.put_change(changeset, :scene_sid, "#{scene_sid}")
  end
end
