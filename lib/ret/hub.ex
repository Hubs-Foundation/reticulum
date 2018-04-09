defmodule Ret.Hub.HubSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug

  def get_sources(_changeset, _opts) do
    [:hub_sid, :name]
  end
end

defmodule Ret.Hub do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.Hub
  alias Ret.Hub.HubSlug

  use Bitwise

  @schema_prefix "ret0"
  @primary_key {:hub_id, :integer, []}

  schema "hubs" do
    field(:name, :string)
    field(:hub_sid, :string)
    field(:default_environment_gltf_bundle_url, :string)
    field(:slug, HubSlug.Type)
    field(:max_occupant_count, :integer)

    timestamps()
  end

  def changeset(%Hub{} = hub, attrs) do
    hub
    |> cast(attrs, [:name, :default_environment_gltf_bundle_url])
    |> validate_required([:name, :default_environment_gltf_bundle_url])
    |> validate_length(:name, min: 4, max: 64)
    |> validate_format(:name, ~r/^[A-Za-z0-9-':"!@#$%^&*(),.?~ ]+$/)
    |> add_hub_sid_to_changeset
    |> unique_constraint(:hub_sid)
    |> HubSlug.maybe_generate_slug()
    |> HubSlug.unique_constraint()
  end

  def changeset_for_new_max_occupants(%Hub{} = hub, attrs) do
    hub
    |> cast(attrs, [:max_occupant_count])
    |> validate_required([:max_occupant_count])
  end

  defp add_hub_sid_to_changeset(changeset) do
    hub_sid =
      16
      |> :crypto.strong_rand_bytes()
      |> Base.encode32()
      |> String.downcase()
      |> String.slice(0, 7)

    # Prefix with 0 just to make migration off of these links easier.
    Ecto.Changeset.put_change(changeset, :hub_sid, "0#{hub_sid}")
  end

  def janus_room_id_for_hub(hub) do
    # Cap to 53 bits of entropy because of Javascript :/
    with <<room_id::size(53), _::size(11), _::binary>> <- :crypto.hash(:sha256, hub.hub_sid) do
      room_id
    end
  end
end
