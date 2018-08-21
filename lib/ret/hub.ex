defmodule Ret.Hub.HubSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug

  def get_sources(_changeset, _opts) do
    [:hub_sid, :name]
  end
end

defmodule Ret.Hub do
  use Ecto.Schema
  use Bitwise

  import Ecto.Changeset

  alias Ret.Hub
  alias Ret.Hub.{HubSlug}

  use Bitwise

  @schema_prefix "ret0"
  @primary_key {:hub_id, :integer, []}
  @num_random_bits_for_hub_sid 16

  schema "hubs" do
    field(:name, :string)
    field(:hub_sid, :string)
    field(:default_environment_gltf_bundle_url, :string)
    field(:slug, HubSlug.Type)
    field(:max_occupant_count, :integer, default: 0)
    field(:spawned_object_types, :integer, default: 0)
    field(:entry_mode, Ret.Hub.EntryMode)

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

  def changeset_for_new_seen_occupant_count(%Hub{} = hub, occupant_count) do
    new_max_occupant_count = max(hub.max_occupant_count, occupant_count)

    hub
    |> cast(%{max_occupant_count: new_max_occupant_count}, [:max_occupant_count])
    |> validate_required([:max_occupant_count])
  end

  def changeset_for_new_spawned_object_type(%Hub{} = hub, object_type)
      when object_type in 1..32 do
    # spawned_object_types is a bitmask of the seen object types
    new_spawned_object_types = hub.spawned_object_types ||| 1 <<< object_type

    hub
    |> cast(%{spawned_object_types: new_spawned_object_types}, [:spawned_object_types])
    |> validate_required([:spawned_object_types])
  end

  def changeset_to_deny_entry(%Hub{} = hub) do
    hub
    |> cast(%{entry_mode: :deny}, [:entry_mode])
  end

  defp add_hub_sid_to_changeset(changeset) do
    hub_sid =
      @num_random_bits_for_hub_sid
      |> :crypto.strong_rand_bytes()
      |> Base.encode32()
      |> String.downcase()
      |> String.slice(0, 10)

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
