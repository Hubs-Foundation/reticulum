defmodule Ret.Hub.HubSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug, always_change: true

  def get_sources(_changeset, _opts) do
    [:hub_sid, :name]
  end
end

defmodule Ret.Hub do
  use Ecto.Schema
  use Bitwise

  import Ecto.Changeset
  import Ecto.Query
  import Canada, only: [can?: 2]

  alias Ret.{Account, Hub, Repo, Scene, SceneListing, WebPushSubscription, RoomAssigner}
  alias Ret.Hub.{HubSlug}

  @schema_prefix "ret0"
  @primary_key {:hub_id, :id, autogenerate: true}
  @max_entry_code 999_999
  @entry_code_expiration_hours 24
  @max_entry_code_generate_attempts 25

  schema "hubs" do
    field(:name, :string)
    field(:hub_sid, :string)
    field(:host, :string)
    field(:entry_code, :integer)
    field(:entry_code_expires_at, :utc_datetime)
    field(:default_environment_gltf_bundle_url, :string)
    field(:slug, HubSlug.Type)
    field(:max_occupant_count, :integer, default: 0)
    field(:spawned_object_types, :integer, default: 0)
    field(:entry_mode, Ret.Hub.EntryMode)
    belongs_to(:scene, Ret.Scene, references: :scene_id)
    belongs_to(:scene_listing, Ret.SceneListing, references: :scene_listing_id)
    has_many(:web_push_subscriptions, Ret.WebPushSubscription, foreign_key: :hub_id)
    belongs_to(:created_by_account, Ret.Account, references: :account_id)
    has_many(:hub_bindings, Ret.HubBinding, foreign_key: :hub_id)

    timestamps()
  end

  def get_by_entry_code_string(entry_code_string) when is_binary(entry_code_string) do
    case Integer.parse(entry_code_string) do
      {entry_code, _} -> Hub |> Repo.get_by(entry_code: entry_code)
      _ -> nil
    end
  end

  def changeset(%Hub{} = hub, %Scene{} = scene, attrs) do
    hub
    |> changeset(nil, attrs)
    |> put_assoc(:scene, scene)
  end

  def changeset(%Hub{} = hub, %SceneListing{} = scene_listing, attrs) do
    hub
    |> changeset(nil, attrs)
    |> put_assoc(:scene_listing, scene_listing)
  end

  def changeset(%Hub{} = hub, nil, attrs) do
    hub
    |> cast(attrs, [:default_environment_gltf_bundle_url])
    |> add_name_to_changeset(attrs)
    |> add_hub_sid_to_changeset
    |> add_entry_code_to_changeset
    |> unique_constraint(:hub_sid)
    |> unique_constraint(:entry_code)
  end

  def add_name_to_changeset(changeset, attrs) do
    changeset
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, max: 64)
    |> HubSlug.maybe_generate_slug()
  end

  def changeset_for_new_seen_occupant_count(%Hub{} = hub, occupant_count) do
    new_max_occupant_count = max(hub.max_occupant_count, occupant_count)

    hub
    |> cast(%{max_occupant_count: new_max_occupant_count}, [:max_occupant_count])
    |> validate_required([:max_occupant_count])
  end

  def changeset_for_new_scene(%Hub{} = hub, %Scene{} = scene) do
    hub
    |> cast(%{}, [])
    |> put_change(:scene_id, scene.scene_id)
    |> put_change(:scene_listing_id, nil)
  end

  def changeset_for_new_scene(%Hub{} = hub, %SceneListing{} = scene_listing) do
    hub
    |> cast(%{}, [])
    |> put_change(:scene_listing_id, scene_listing.scene_listing_id)
    |> put_change(:scene_id, nil)
  end

  def changeset_for_new_environment_url(%Hub{} = hub, url) do
    hub
    |> cast(%{default_environment_gltf_bundle_url: url}, [:default_environment_gltf_bundle_url])
    |> validate_required([:default_environment_gltf_bundle_url])
  end

  def changeset_for_new_spawned_object_type(%Hub{} = hub, object_type)
      when object_type in 0..31 do
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

  def changeset_for_new_host(%Hub{} = hub, host) do
    hub |> cast(%{host: host}, [:host])
  end

  def add_account_to_changeset(changeset, nil), do: changeset

  def add_account_to_changeset(changeset, %Account{} = account) do
    changeset |> put_assoc(:created_by_account, account)
  end

  def send_push_messages_for_join(%Hub{web_push_subscriptions: subscriptions} = hub, endpoint_to_skip \\ nil) do
    body = hub |> push_message_for_join

    for subscription <- subscriptions |> Enum.filter(&(&1.endpoint != endpoint_to_skip)) do
      subscription |> WebPushSubscription.maybe_send(body)
    end
  end

  defp push_message_for_join(%Hub{} = hub) do
    %{type: "join", hub_name: hub.name, hub_id: hub.hub_sid, hub_url: hub |> url_for, image: hub |> image_url_for}
    |> Poison.encode!()
  end

  def url_for(%Hub{} = hub) do
    "#{RetWeb.Endpoint.url()}/#{hub.hub_sid}/#{hub.slug}"
  end

  def image_url_for(%Hub{scene: nil}) do
    "#{RetWeb.Endpoint.url()}/hub-preview.png"
  end

  def image_url_for(%Hub{scene: scene}) do
    scene.screenshot_owned_file |> Ret.OwnedFile.uri_for() |> URI.to_string()
  end

  defp changeset_for_new_entry_code(%Hub{} = hub) do
    hub
    |> Ecto.Changeset.change()
    |> add_entry_code_to_changeset
  end

  def ensure_valid_entry_code!(hub) do
    if hub |> entry_code_expired? do
      hub |> changeset_for_new_entry_code |> Repo.update!()
    else
      hub
    end
  end

  def ensure_host(hub) do
    if RoomAssigner.is_alive?(hub.host) do
      hub
    else
      # TODO the database mutation should be centralized into the GenServer
      # to ensure a partition doesn't cause a rogue node to re-assign the server
      host = RoomAssigner.get_available_host(hub.host)

      if host && host != hub.host do
        hub |> changeset_for_new_host(host) |> Repo.update!()
      else
        hub
      end
    end
  end

  def entry_code_expired?(%Hub{entry_code: entry_code, entry_code_expires_at: entry_code_expires_at})
      when is_nil(entry_code) or is_nil(entry_code_expires_at),
      do: true

  def entry_code_expired?(%Hub{} = hub) do
    Timex.now() |> Timex.after?(hub.entry_code_expires_at)
  end

  def vacuum_entry_codes do
    query = from(h in Hub, where: h.entry_code_expires_at() < ^Timex.now())
    Repo.update_all(query, set: [entry_code: nil, entry_code_expires_at: nil])
  end

  # Remove the host entry from any rooms that are older than a day old and have no presence
  def vacuum_hosts do
    one_day_ago = Timex.now() |> Timex.shift(days: -1)

    candidate_hub_sids =
      from(h in Hub, where: not is_nil(h.host) and h.inserted_at < ^one_day_ago) |> Repo.all() |> Enum.map(& &1.hub_sid)

    present_hub_sids = RetWeb.Presence.present_hub_sids()
    clearable_hub_sids = candidate_hub_sids |> Enum.filter(&(!Enum.member?(present_hub_sids, &1)))

    from(h in Hub, where: h.hub_sid in ^clearable_hub_sids) |> Repo.update_all(set: [host: nil])
  end

  defp add_hub_sid_to_changeset(changeset) do
    hub_sid = Ret.Sids.generate_sid()
    changeset |> put_change(:hub_sid, hub_sid)
  end

  defp add_entry_code_to_changeset(changeset) do
    expires_at = Timex.now() |> Timex.shift(hours: @entry_code_expiration_hours)

    changeset
    |> put_change(:entry_code, generate_entry_code!())
    |> put_change(:entry_code_expires_at, expires_at)
  end

  defp generate_entry_code!(attempt \\ 0)

  defp generate_entry_code!(attempt) when attempt > @max_entry_code_generate_attempts do
    raise "Unable to allocate entry code"
  end

  defp generate_entry_code!(attempt) do
    candidate_entry_code = :rand.uniform(@max_entry_code)

    case Hub |> Repo.get_by(entry_code: candidate_entry_code) do
      nil -> candidate_entry_code
      _ -> generate_entry_code!(attempt + 1)
    end
  end

  def janus_room_id_for_hub(hub) do
    # Cap to 53 bits of entropy because of Javascript :/
    with <<room_id::size(53), _::size(11), _::binary>> <- :crypto.hash(:sha256, hub.hub_sid) do
      room_id
    end
  end

  def perms_for_account(%Ret.Hub{} = hub, account) do
    %{
      join_hub: account |> can?(join_hub(hub)),
      update_hub: account |> can?(update_hub(hub)),
      kick_users: account |> can?(kick_users(hub)),
      mute_users: account |> can?(mute_users(hub))
    }
  end
end

defimpl Canada.Can, for: Ret.Account do
  # Only creators can perform these actions
  def can?(%Ret.Account{account_id: account_id}, action, %Ret.Hub{created_by_account_id: account_id})
      when account_id != nil and action in [:update_hub, :kick_users, :mute_users],
      do: true

  # Anyone can join an unbound hub
  def can?(_, :join_hub, %Ret.Hub{hub_bindings: hub_bindings}) when length(hub_bindings) == 0, do: true

  # Bound hubs require accounts to have an oauth provider
  def can?(%Ret.Account{oauth_providers: oauth_providers}, :join_hub, hub) when length(oauth_providers) == 0, do: false

  def can?(account, :join_hub, hub) do
    hub.hub_bindings
    |> Enum.any?(fn binding ->
      provider = account.oauth_providers |> Enum.find(&(&1.source == binding.type))

      if provider do
        case provider.source do
          :discord ->
            provider.provider_account_id
            |> Ret.DiscordClient.member_of_channel?(binding.community_id, binding.channel_id)
        end
      end
    end)
  end

  def can?(_, _, _), do: false
end

# Permissions for un-authenticated clients
defimpl Canada.Can, for: Atom do
  # Anyone can join an unbound hub
  def can?(_, :join_hub, %Ret.Hub{hub_bindings: hub_bindings}) when length(hub_bindings) == 0, do: true

  def can?(_, _, _), do: false
end
