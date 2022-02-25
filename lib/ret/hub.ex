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

  alias Ret.{
    Account,
    Hub,
    Repo,
    Scene,
    SceneListing,
    WebPushSubscription,
    RoomAssigner,
    BitFieldUtils,
    HubRoleMembership,
    AppConfig,
    AccountFavorite
  }

  alias Ret.Hub.{HubSlug}

  @schema_prefix "ret0"
  @primary_key {:hub_id, :id, autogenerate: true}

  @member_permissions %{
    (1 <<< 0) => :spawn_and_move_media,
    (1 <<< 1) => :spawn_camera,
    (1 <<< 2) => :spawn_drawing,
    (1 <<< 3) => :pin_objects,
    (1 <<< 4) => :spawn_emoji,
    (1 <<< 5) => :fly
  }

  @member_permissions_keys @member_permissions |> Map.values()

  @default_member_permissions %{
    spawn_and_move_media: true,
    spawn_camera: true,
    spawn_drawing: true,
    pin_objects: true,
    spawn_emoji: true,
    fly: true
  }

  @default_restrictive_member_permissions %{
    spawn_and_move_media: false,
    spawn_camera: false,
    spawn_drawing: false,
    pin_objects: false,
    spawn_emoji: false,
    fly: false
  }

  def hub_preloads() do
    [
      scene: Scene.scene_preloads(),
      scene_listing: [
        :model_owned_file,
        :screenshot_owned_file,
        :scene_owned_file,
        :project,
        :account,
        scene: Scene.scene_preloads()
      ],
      web_push_subscriptions: [],
      hub_bindings: [],
      created_by_account: [],
      hub_role_memberships: []
    ]
  end

  schema "hubs" do
    field(:name, :string)
    field(:description, :string)
    field(:hub_sid, :string)
    field(:host, :string)
    field(:last_active_at, :utc_datetime)
    field(:creator_assignment_token, :string)
    field(:embed_token, :string)
    field(:embedded, :boolean)
    field(:member_permissions, :integer)
    field(:default_environment_gltf_bundle_url, :string)
    field(:slug, HubSlug.Type)
    field(:max_occupant_count, :integer, default: 0)
    field(:spawned_object_types, :integer, default: 0)
    field(:entry_mode, Ret.Hub.EntryMode)
    field(:user_data, :map)
    belongs_to(:scene, Ret.Scene, references: :scene_id, on_replace: :nilify)
    belongs_to(:scene_listing, Ret.SceneListing, references: :scene_listing_id, on_replace: :nilify)
    has_many(:web_push_subscriptions, Ret.WebPushSubscription, foreign_key: :hub_id)
    belongs_to(:created_by_account, Ret.Account, references: :account_id)
    has_many(:hub_invites, Ret.HubInvite, foreign_key: :hub_id)
    has_many(:hub_bindings, Ret.HubBinding, foreign_key: :hub_id)
    has_many(:hub_role_memberships, Ret.HubRoleMembership, foreign_key: :hub_id)

    field(:allow_promotion, :boolean)

    field(:room_size, :integer)

    timestamps()
  end

  @required_keys [
    :name,
    :hub_sid,
    :host,
    :embed_token,
    :member_permissions,
    :max_occupant_count,
    :spawned_object_types,
    :room_size
  ]
  @permitted_keys [
    :creator_assignment_token,
    :description,
    :embedded,
    :default_environment_gltf_bundle_url,
    :user_data,
    :last_active_at,
    :entry_mode | @required_keys
  ]

  # TODO: This function was created for use in the public API.
  #       It would be good to revisit this and the alternatives below
  #       so that there did not need to be as many variations.
  def create_room(params, account_or_nil) do
    with {:ok, params} <- parse_member_permissions(params) do
      params =
        Map.merge(
          %{
            name: Ret.RandomRoomNames.generate_room_name(),
            hub_sid: Ret.Sids.generate_sid(),
            host: RoomAssigner.get_available_host(nil),
            creator_assignment_token: SecureRandom.hex(),
            embed_token: SecureRandom.hex(),
            member_permissions: default_member_permissions(),
            room_size: AppConfig.get_cached_config_value("features|default_room_size")
          },
          params
        )

      result =
        %Hub{}
        |> change()
        |> cast(params, @permitted_keys)
        |> add_account_to_changeset(account_or_nil)
        |> add_scene_changes_to_changeset(params)
        |> HubSlug.maybe_generate_slug()
        |> validate_required(@required_keys)
        |> validate_length(:name, max: 64)
        |> validate_length(:description, max: 64_000)
        |> validate_number(:room_size,
          greater_than_or_equal_to: 0,
          less_than_or_equal_to: AppConfig.get_cached_config_value("features|max_room_size")
        )
        |> unique_constraint(:hub_sid)
        |> Repo.insert()

      case result do
        {:ok, hub} ->
          {:ok, Repo.preload(hub, hub_preloads())}

        _ ->
          result
      end
    end
  end

  # TODO: Clean up handling of member_permissions so that it is
  # clear everywhere whether we are dealing with a map or an int
  defp parse_member_permissions(%{member_permissions: map} = params) when is_map(map) do
    case Hub.lenient_member_permissions_to_int(map) do
      {:ok, member_permissions} ->
        {:ok, %{params | member_permissions: member_permissions}}

      {ArgumentError, e} ->
        {:error, e}
    end
  end

  defp parse_member_permissions(%{member_permissions: nil} = params) do
    {:ok, Map.delete(params, :member_permissions)}
  end

  defp parse_member_permissions(params) do
    {:ok, params}
  end

  defp default_member_permissions() do
    if Ret.AppConfig.get_config_bool("features|permissive_rooms") do
      member_permissions_to_int(@default_member_permissions)
    else
      member_permissions_to_int(@default_restrictive_member_permissions)
    end
  end

  def add_scene_changes_to_changeset(changeset, %{} = params) do
    add_scene_changes(changeset, scene_change_from_params(params))
  end

  defp scene_change_from_params(%{scene_id: nil, scene_url: nil}) do
    :nilify
  end

  defp scene_change_from_params(%{scene_id: _id, scene_url: _url}) do
    {:error,
     %{key: :scene_id, message: "Cannot specify both scene_id and scene_url. Choose one or the other (or neither)."}}
  end

  defp scene_change_from_params(%{scene_url: nil}) do
    :nilify
  end

  defp scene_change_from_params(%{scene_id: nil}) do
    :nilify
  end

  defp scene_change_from_params(%{scene_url: url}) do
    endpoint_host = RetWeb.Endpoint.host()

    case url |> URI.parse() do
      %URI{host: ^endpoint_host, path: "/scenes/" <> scene_path} ->
        scene_or_scene_listing = scene_path |> String.split("/") |> Enum.at(0) |> Scene.scene_or_scene_listing_by_sid()

        if is_nil(scene_or_scene_listing) do
          {:error, %{key: :scene_url, message: "Cannot find scene with url: " <> url}}
        else
          scene_or_scene_listing
        end

      _ ->
        url
    end
  end

  defp scene_change_from_params(%{scene_id: id}) do
    scene_or_scene_listing = Scene.scene_or_scene_listing_by_sid(id)

    if is_nil(scene_or_scene_listing) do
      {:error, %{key: :scene_id, message: "Cannot find scene with id: " <> id}}
    else
      scene_or_scene_listing
    end
  end

  defp scene_change_from_params(_params) do
    nil
  end

  defp add_scene_changes(changeset, {:error, %{key: key, message: message}}) do
    add_error(changeset, key, message)
  end

  defp add_scene_changes(changeset, nil) do
    # No scene info in params. Leave unchanged
    changeset
  end

  defp add_scene_changes(changeset, :nilify) do
    # Clear scene info
    changeset
    |> put_change(:default_environment_gltf_bundle_url, nil)
    |> put_assoc(:scene, nil)
    |> put_assoc(:scene_listing, nil)
  end

  defp add_scene_changes(changeset, %Scene{} = scene) do
    changeset
    |> put_assoc(:scene, scene)
    |> put_assoc(:scene_listing, nil)
    |> put_change(:default_environment_gltf_bundle_url, nil)
  end

  defp add_scene_changes(changeset, %SceneListing{} = scene_listing) do
    changeset
    |> put_assoc(:scene, nil)
    |> put_assoc(:scene_listing, scene_listing)
    |> put_change(:default_environment_gltf_bundle_url, nil)
  end

  defp add_scene_changes(changeset, url) do
    changeset
    |> cast(%{default_environment_gltf_bundle_url: url}, [:default_environment_gltf_bundle_url])
    # TODO: Should we validate the format of the URL?
    |> validate_required([:default_environment_gltf_bundle_url])
    |> put_assoc(:scene, nil)
    |> put_assoc(:scene_listing, nil)
  end

  # Create new room, inserts into db
  # returns newly created %Hub
  def create_new_room(%{"name" => _name} = params, true = _add_to_db) do
    scene_or_scene_listing = get_scene_or_scene_listing(params)

    %Hub{}
    |> changeset(scene_or_scene_listing, params)
    |> Repo.insert()
  end

  # Create new room, does NOT insert into db
  # returns newly created %Hub
  def create_new_room(%{"name" => _name} = params, false = _add_to_db) do
    scene_or_scene_listing = get_scene_or_scene_listing(params)

    %Hub{}
    |> changeset(scene_or_scene_listing, params)
  end

  def create(params) do
    scene_or_scene_listing = get_scene_or_scene_listing(params)

    %Hub{}
    |> changeset(scene_or_scene_listing, params)
    |> Repo.insert()
  end

  defp get_scene_or_scene_listing(params) do
    if is_nil(params["scene_id"]) do
      SceneListing.get_random_default_scene_listing()
    else
      Scene.scene_or_scene_listing_by_sid(params["scene_id"])
    end
  end

  defp get_scene_or_scene_listing_by_id(nil) do
    SceneListing.get_random_default_scene_listing()
  end

  defp get_scene_or_scene_listing_by_id(id) do
    Scene.scene_or_scene_listing_by_sid(id)
  end

  def get_my_rooms(account, params) do
    Hub
    |> where([h], h.created_by_account_id == ^account.account_id and h.entry_mode in ^["allow", "invite"])
    |> order_by(desc: :inserted_at)
    |> preload(^Hub.hub_preloads())
    |> Repo.paginate(params)
  end

  def get_favorite_rooms(account, params) do
    Hub
    |> where([h], h.entry_mode in ^["allow", "invite"])
    |> join(:inner, [h], f in AccountFavorite, on: f.hub_id == h.hub_id and f.account_id == ^account.account_id)
    |> order_by([h, f], desc: f.last_activated_at)
    |> preload(^Hub.hub_preloads())
    |> Repo.paginate(params)
  end

  def get_public_rooms(params) do
    Hub
    |> where([h], h.allow_promotion and h.entry_mode in ^["allow", "invite"])
    |> order_by(desc: :inserted_at)
    |> preload(^Hub.hub_preloads())
    |> Repo.paginate(params)
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
    |> add_attrs_to_changeset(attrs)
    |> add_hub_sid_to_changeset
    |> add_generated_tokens_to_changeset
    |> add_default_member_permissions_to_changeset
    |> unique_constraint(:hub_sid)
  end

  def add_attrs_to_changeset(changeset, attrs) do
    changeset
    |> cast(attrs, [:name, :description, :user_data, :room_size])
    |> validate_required([:name])
    |> validate_length(:name, max: 64)
    |> validate_length(:description, max: 64_000)
    |> validate_number(:room_size,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: AppConfig.get_cached_config_value("features|max_room_size")
    )
    |> HubSlug.maybe_generate_slug()
  end

  def member_permissions_from_attrs(%{} = attrs) do
    attrs["member_permissions"] |> Map.new(fn {k, v} -> {String.to_atom(k), v} end) |> member_permissions_to_int
  end

  defp add_member_permissions_update_to_changeset(changeset, hub, member_permissions) do
    member_permissions =
      Map.merge(member_permissions_for_hub(hub), member_permissions)
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
      |> member_permissions_to_int

    changeset
    |> put_change(:member_permissions, member_permissions)
  end

  def add_member_permissions_to_changeset(changeset, attrs) do
    member_permissions = attrs |> member_permissions_from_attrs

    changeset
    |> put_change(:member_permissions, member_permissions)
  end

  def maybe_add_promotion_to_changeset(changeset, account, hub, attrs) do
    can_change_promotion = account |> can?(update_hub_promotion(hub))
    if can_change_promotion, do: changeset |> add_promotion_to_changeset(attrs), else: changeset
  end

  def add_promotion_to_changeset(changeset, attrs) do
    changeset
    |> put_change(:allow_promotion, Map.get(attrs, "allow_promotion", false) || Map.get(attrs, :allow_promotion, false))
  end

  def maybe_add_entry_mode_to_changeset(changeset, attrs) do
    if attrs["entry_mode"] === nil do
      changeset
    else
      changeset |> put_change(:entry_mode, attrs["entry_mode"])
    end
  end

  def maybe_add_new_scene_to_changeset(changeset, %{scene_id: scene_id}) do
    scene_or_scene_listing = get_scene_or_scene_listing_by_id(scene_id)

    if is_nil(scene_or_scene_listing) do
      {:error, "Cannot find scene with id " <> scene_id}
    else
      Hub.add_new_scene_to_changeset(changeset, scene_or_scene_listing)
    end
  end

  def maybe_add_new_scene_to_changeset(changeset, _args) do
    changeset
  end

  def changeset_for_new_seen_occupant_count(%Hub{} = hub, occupant_count) do
    new_max_occupant_count = max(hub.max_occupant_count, occupant_count)

    hub
    |> cast(%{max_occupant_count: new_max_occupant_count}, [:max_occupant_count])
    |> maybe_add_last_active_at_to_changeset(occupant_count)
    |> validate_required([:max_occupant_count])
  end

  def changeset_for_seen_embedded_hub(%Hub{} = hub), do: hub |> cast(%{embedded: true}, [:embedded])

  # NOTE occupant_count is 1 when there is 1 *other* user in the room with you, so active is when >= 1.
  defp maybe_add_last_active_at_to_changeset(changeset, occupant_count) when occupant_count >= 1,
    do: changeset |> put_change(:last_active_at, Timex.now() |> DateTime.truncate(:second))

  defp maybe_add_last_active_at_to_changeset(changeset, _), do: changeset

  def changeset_for_new_scene(%Hub{} = hub, %Scene{} = scene) do
    hub
    |> change()
    |> add_new_scene_to_changeset(scene)
  end

  def changeset_for_new_scene(%Hub{} = hub, %SceneListing{} = scene_listing) do
    hub
    |> change()
    |> add_new_scene_to_changeset(scene_listing)
  end

  def add_new_scene_to_changeset(changeset, %Scene{} = scene) do
    changeset
    |> put_change(:scene_id, scene.scene_id)
    |> put_change(:scene_listing_id, nil)
  end

  def add_new_scene_to_changeset(changeset, %SceneListing{} = scene_listing) do
    changeset
    |> put_change(:scene_listing_id, scene_listing.scene_listing_id)
    |> put_change(:scene_id, nil)
  end

  def changeset_for_new_environment_url(%Hub{} = hub, url) do
    hub
    |> cast(%{default_environment_gltf_bundle_url: url}, [:default_environment_gltf_bundle_url])
    |> validate_required([:default_environment_gltf_bundle_url])
    |> put_change(:scene_id, nil)
    |> put_change(:scene_listing_id, nil)
  end

  def changeset_for_new_spawned_object_type(%Hub{} = hub, object_type)
      when object_type in 0..31 do
    # spawned_object_types is a bitmask of the seen object types
    new_spawned_object_types = hub.spawned_object_types ||| 1 <<< object_type

    hub
    |> cast(%{spawned_object_types: new_spawned_object_types}, [:spawned_object_types])
    |> validate_required([:spawned_object_types])
  end

  def changeset_for_entry_mode(%Hub{} = hub, entry_mode),
    do: hub |> cast(%{entry_mode: entry_mode}, [:entry_mode])

  def changeset_for_new_host(%Hub{} = hub, host), do: hub |> cast(%{host: host}, [:host])

  def changeset_for_creator_assignment(
        %Ret.Hub{creator_assignment_token: expected_token} = hub,
        account,
        token
      )
      when expected_token != nil and expected_token == token do
    hub |> change() |> add_account_to_changeset(account)
  end

  def changeset_for_creator_assignment(hub, _, _), do: hub |> change()

  def add_account_to_changeset(changeset, nil), do: changeset

  def add_account_to_changeset(changeset, %Account{} = account) do
    changeset |> put_assoc(:created_by_account, account) |> put_change(:creator_assignment_token, nil)
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

  def image_url_for(%Hub{scene: nil, scene_listing: nil}) do
    "#{RetWeb.Endpoint.url()}/app-thumbnail.png"
  end

  def image_url_for(%Hub{scene: scene}) when scene != nil do
    scene.screenshot_owned_file |> Ret.OwnedFile.uri_for() |> URI.to_string()
  end

  def image_url_for(%Hub{scene_listing: scene_listing}) when scene_listing != nil do
    scene_listing.screenshot_owned_file |> Ret.OwnedFile.uri_for() |> URI.to_string()
  end

  def member_count_for(%Hub{hub_sid: hub_sid}), do: member_count_for(hub_sid)

  def member_count_for(hub_sid) do
    RetWeb.Presence.list("hub:#{hub_sid}")
    |> Enum.filter(fn {_, %{metas: m}} ->
      m |> Enum.any?(fn %{presence: p, context: c} -> p == :room and !(c != nil and Map.get(c, "discord", false)) end)
    end)
    |> Enum.count()
  end

  def lobby_count_for(%Hub{hub_sid: hub_sid}), do: lobby_count_for(hub_sid)

  def lobby_count_for(hub_sid) do
    RetWeb.Presence.list("hub:#{hub_sid}")
    |> Enum.filter(fn {_, %{metas: m}} ->
      m |> Enum.any?(fn %{presence: p, context: c} -> p == :lobby and !(c != nil and Map.get(c, "discord", false)) end)
    end)
    |> Enum.count()
  end

  def room_size_for(%Hub{} = hub) do
    hub.room_size || AppConfig.get_cached_config_value("features|default_room_size")
  end

  def scene_or_scene_listing_for(%Hub{} = hub) do
    case hub.scene || hub.scene_listing do
      nil -> nil
      %Scene{state: :removed} -> nil
      %SceneListing{state: :delisted} -> nil
      scene_or_scene_listing -> scene_or_scene_listing
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

  # Remove the host entry from any rooms that are older than a day old and have no presence
  def vacuum_hosts do
    Ret.Locking.exec_if_lockable(:hub_vacuum_hosts, fn ->
      one_day_ago = Timex.now() |> Timex.shift(days: -1)

      candidate_hub_sids =
        from(h in Hub, where: not is_nil(h.host) and h.inserted_at < ^one_day_ago)
        |> Repo.all()
        |> Enum.map(& &1.hub_sid)

      present_hub_sids = RetWeb.Presence.present_hub_sids()
      clearable_hub_sids = candidate_hub_sids |> Enum.filter(&(!Enum.member?(present_hub_sids, &1)))

      from(h in Hub, where: h.hub_sid in ^clearable_hub_sids) |> Repo.update_all(set: [host: nil])
    end)
  end

  defp add_hub_sid_to_changeset(changeset) do
    hub_sid = Ret.Sids.generate_sid()
    changeset |> put_change(:hub_sid, hub_sid)
  end

  defp add_generated_tokens_to_changeset(changeset) do
    creator_assignment_token = SecureRandom.hex()
    embed_token = SecureRandom.hex()

    changeset
    |> put_change(:creator_assignment_token, creator_assignment_token)
    |> put_change(:embed_token, embed_token)
  end

  def janus_room_id_for_hub(hub) do
    # Cap to 53 bits of entropy because of Javascript :/
    with <<room_id::size(53), _::size(11), _::binary>> <- :crypto.hash(:sha256, hub.hub_sid) do
      room_id
    end
  end

  def janus_port do
    Application.get_env(:ret, Ret.JanusLoadStatus)[:janus_port]
  end

  def generate_turn_info do
    if Ret.Coturn.enabled?() do
      {username, credential} = Ret.Coturn.generate_credentials()

      transports =
        (Application.get_env(:ret, Ret.Coturn)[:public_tls_ports] || "5349")
        |> String.split(",")
        |> Enum.map(&%{port: &1 |> Integer.parse() |> elem(0)})

      %{enabled: true, username: username, credential: credential, transports: transports}
    else
      %{enabled: false}
    end
  end

  defp add_default_member_permissions_to_changeset(changeset) do
    if Ret.AppConfig.get_config_bool("features|permissive_rooms") do
      changeset |> put_change(:member_permissions, @default_member_permissions |> member_permissions_to_int)
    else
      changeset |> put_change(:member_permissions, @default_restrictive_member_permissions |> member_permissions_to_int)
    end
  end

  def add_owner!(%Hub{created_by_account_id: created_by_account_id} = hub, %Account{account_id: account_id})
      when created_by_account_id != nil and created_by_account_id === account_id,
      do: hub

  def add_owner!(%Hub{} = hub, %Account{} = account) do
    Repo.get_by(HubRoleMembership, hub_id: hub.hub_id, account_id: account.account_id) ||
      %HubRoleMembership{} |> HubRoleMembership.changeset(hub, account) |> Repo.insert!()

    hub |> Repo.preload([hub_role_memberships: []], force: true)
  end

  def remove_owner!(%Hub{} = hub, %Account{} = account) do
    case Repo.get_by(HubRoleMembership, hub_id: hub.hub_id, account_id: account.account_id) do
      %HubRoleMembership{} = membership ->
        membership |> Repo.delete!()

      _ ->
        nil
    end

    hub |> Repo.preload([hub_role_memberships: []], force: true)
  end

  def is_creator?(%Hub{created_by_account_id: created_by_account_id}, account_id)
      when created_by_account_id != nil and created_by_account_id === account_id,
      do: true

  def is_creator?(_hub, _account), do: false

  def is_owner?(%Hub{hub_role_memberships: hub_role_memberships} = hub, account_id) do
    is_creator?(hub, account_id) || hub_role_memberships |> Enum.any?(&(&1.account_id === account_id))
  end

  @doc """
  Lenient version of member permissions conversion
  Does not throw on invalid permissions
  """
  def lenient_member_permissions_to_int(%{} = member_permissions) do
    invalid_member_permissions = member_permissions |> Map.drop(@member_permissions_keys) |> Map.keys()

    if invalid_member_permissions |> Enum.count() > 0 do
      {ArgumentError, "Invalid permissions #{invalid_member_permissions |> Enum.join(", ")}"}
    else
      {:ok,
       @member_permissions
       |> Enum.reduce(0, fn {val, member_permission}, acc ->
         if(member_permissions[member_permission], do: val, else: 0) + acc
       end)}
    end
  end

  # TODO: Rename (lenient_)member_permissions_to_int
  # to follow the elixir pattern of using an exclamation mark (!)
  # to indicate possibly raising an error
  def member_permissions_to_int(%{} = member_permissions) do
    case lenient_member_permissions_to_int(member_permissions) do
      {:ok, int} ->
        int

      {ArgumentError, e} ->
        raise ArgumentError, e
    end
  end

  def has_member_permission?(%Hub{} = hub, member_permission) do
    case @member_permissions
         |> Enum.find(fn {_, member_permission_name} -> member_permission_name == member_permission end) do
      nil -> raise ArgumentError, "Invalid permission #{member_permission}"
      {val, _} -> (hub.member_permissions &&& val) > 0
    end
  end

  def member_permissions_for_hub(%Hub{} = hub) do
    hub.member_permissions
    |> BitFieldUtils.permissions_to_map(@member_permissions)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  def member_permissions_for_hub_as_atoms(%Hub{} = hub) do
    hub.member_permissions
    |> BitFieldUtils.permissions_to_map(@member_permissions)
  end

  def maybe_add_member_permissions(changeset, hub, %{"member_permissions" => member_permissions}) do
    add_member_permissions_update_to_changeset(
      changeset,
      hub,
      member_permissions
    )
  end

  def maybe_add_member_permissions(changeset, _hub, %{:member_permissions => nil}) do
    changeset
  end

  def maybe_add_member_permissions(changeset, hub, %{:member_permissions => member_permissions}) do
    add_member_permissions_update_to_changeset(
      changeset,
      hub,
      Map.new(member_permissions, fn {k, v} -> {Atom.to_string(k), v} end)
    )
  end

  def maybe_add_member_permissions(changeset, _hub, _params) do
    changeset
  end

  def maybe_add_promotion(changeset, account, hub, %{"allow_promotion" => _} = hub_params),
    do: changeset |> Hub.maybe_add_promotion_to_changeset(account, hub, hub_params)

  def maybe_add_promotion(changeset, account, hub, %{allow_promotion: _} = hub_params),
    do: changeset |> Hub.maybe_add_promotion_to_changeset(account, hub, hub_params)

  def maybe_add_promotion(changeset, _account, _hub, _), do: changeset

  # The account argument here can be a Ret.Account, a Ret.OAuthProvider or nil.
  def perms_for_account(%Ret.Hub{} = hub, account) do
    %{
      join_hub: account |> can?(join_hub(hub)),
      update_hub: account |> can?(update_hub(hub)),
      update_hub_promotion: account |> can?(update_hub_promotion(hub)),
      update_roles: account |> can?(update_roles(hub)),
      close_hub: account |> can?(close_hub(hub)),
      embed_hub: account |> can?(embed_hub(hub)),
      kick_users: account |> can?(kick_users(hub)),
      mute_users: account |> can?(mute_users(hub)),
      amplify_audio: account |> can?(amplify_audio(hub)),
      spawn_camera: account |> can?(spawn_camera(hub)),
      spawn_drawing: account |> can?(spawn_drawing(hub)),
      spawn_and_move_media: account |> can?(spawn_and_move_media(hub)),
      pin_objects: account |> can?(pin_objects(hub)),
      spawn_emoji: account |> can?(spawn_emoji(hub)),
      fly: account |> can?(fly(hub))
    }
  end

  def roles_for_account(%Ret.Hub{}, nil),
    do: %{owner: false, creator: false, signed_in: false}

  def roles_for_account(%Ret.Hub{} = hub, account),
    do: %{owner: hub |> is_owner?(account.account_id), creator: hub |> is_creator?(account.account_id), signed_in: true}
end

defimpl Canada.Can, for: Ret.Account do
  alias Ret.{Hub, AppConfig}
  alias Ret.Api.Credentials

  def can?(%Ret.Account{is_admin: is_admin}, :create_credentials, _params) do
    is_admin
  end

  def can?(%Ret.Account{is_admin: is_admin}, :list_credentials, :app) do
    is_admin
  end

  def can?(%Ret.Account{}, :list_credentials, :account) do
    # TODO: Allow admins to disable this in config
    true
  end

  def can?(%Ret.Account{}, :list_credentials, _subject_type) do
    false
  end

  def can?(%Ret.Account{account_id: account_id}, :revoke_credentials, %Credentials{account_id: account_id}) do
    true
  end

  def can?(%Ret.Account{is_admin: true}, :revoke_credentials, %Credentials{}) do
    true
  end

  def can?(%Ret.Account{}, :revoke_credentials, %Credentials{}) do
    false
  end

  @owner_actions [:update_hub, :close_hub, :embed_hub, :kick_users, :mute_users, :amplify_audio]
  @object_actions [:spawn_and_move_media, :spawn_camera, :spawn_drawing, :pin_objects, :spawn_emoji, :fly]
  @creator_actions [:update_roles]

  # Always deny all actions to disabled accounts
  def can?(%Ret.Account{state: :disabled}, _, _), do: false

  # Always deny access to non-enterable hubs
  def can?(%Ret.Account{}, :join_hub, %Ret.Hub{entry_mode: :deny}), do: false

  def can?(%Ret.Account{} = account, :update_hub_promotion, %Ret.Hub{} = hub) do
    owners_can_change_promotion = Ret.AppConfig.get_config_bool("features|public_rooms")
    !!account.is_admin or (owners_can_change_promotion and can?(account, :update_hub, hub))
  end

  # Bound hubs - Join perm
  def can?(%Ret.Account{} = account, :join_hub, %Ret.Hub{hub_bindings: hub_bindings})
      when hub_bindings |> length > 0 do
    hub_bindings |> Enum.any?(&(account |> Ret.HubBinding.member_of_channel?(&1)))
  end

  # Bound hubs - Manage actions
  def can?(%Ret.Account{} = account, action, %Ret.Hub{hub_bindings: hub_bindings})
      when action in [:update_hub, :close_hub] and hub_bindings |> length > 0 do
    hub_bindings |> Enum.any?(&(account |> Ret.HubBinding.can_manage_channel?(&1)))
  end

  # Bound hubs - Moderator actions
  def can?(%Ret.Account{} = account, action, %Ret.Hub{hub_bindings: hub_bindings})
      when hub_bindings |> length > 0 and action in [:kick_users, :mute_users, :amplify_audio] do
    hub_bindings |> Enum.any?(&(account |> Ret.HubBinding.can_moderate_users?(&1)))
  end

  # Bound hubs - Object permissions
  def can?(%Ret.Account{} = account, action, %Ret.Hub{hub_bindings: hub_bindings} = hub)
      when hub_bindings |> length > 0 and action in @object_actions do
    is_moderator = hub_bindings |> Enum.any?(&(account |> Ret.HubBinding.can_moderate_users?(&1)))

    if is_moderator do
      true
    else
      is_member = hub_bindings |> Enum.any?(&(account |> Ret.HubBinding.member_of_channel?(&1)))
      is_member and hub |> Hub.has_member_permission?(action)
    end
  end

  # Bound hubs - Always prevent embedding and role assignment (since it's dictated by binding)
  def can?(%Ret.Account{}, action, %Ret.Hub{hub_bindings: hub_bindings})
      when hub_bindings |> length > 0 and action in [:embed_hub, :update_roles],
      do: false

  # Unbound hubs - Anyone can join an unbound hub
  def can?(_account, :join_hub, %Ret.Hub{hub_bindings: []}), do: true

  # Unbound hubs - Creator can perform creator actions
  def can?(%Ret.Account{account_id: account_id}, action, %Ret.Hub{
        created_by_account_id: created_by_account_id,
        hub_bindings: []
      })
      when action in @creator_actions and created_by_account_id != nil and created_by_account_id == account_id,
      do: true

  # Unbound hubs - Owners can perform special actions
  def can?(%Ret.Account{account_id: account_id}, action, %Ret.Hub{hub_bindings: []} = hub)
      when action in @owner_actions,
      do: hub |> Ret.Hub.is_owner?(account_id)

  # Unbound hubs - Object actions can be performed if granted in member permissions or if account is an owner
  def can?(%Ret.Account{account_id: account_id}, action, %Hub{hub_bindings: []} = hub) when action in @object_actions do
    hub |> Hub.has_member_permission?(action) or hub |> Ret.Hub.is_owner?(account_id)
  end

  @self_allowed_actions [:get_rooms_created_by, :get_favorite_rooms_of]
  # Allow accounts to access their own rooms
  def can?(%Ret.Account{} = a, action, %Ret.Account{} = b) when action in @self_allowed_actions,
    do: a.account_id == b.account_id

  def can?(%Ret.Account{}, :get_public_rooms, _), do: true

  # Create hubs
  def can?(%Ret.Account{is_admin: true}, :create_hub, _), do: true

  def can?(_account, :create_hub, _),
    do: !AppConfig.get_cached_config_value("features|disable_room_creation")

  # Create accounts
  def can?(%Ret.Account{is_admin: true}, :create_account, _), do: true
  def can?(_account, :create_account, _), do: !AppConfig.get_cached_config_value("features|disable_sign_up")

  # Deny permissions for any other case that falls through
  def can?(_, _, _), do: false
end

# Perms for oauth users that do not have a hubs account
defimpl Canada.Can, for: Ret.OAuthProvider do
  alias Ret.{AppConfig, Hub}

  @object_actions [:spawn_and_move_media, :spawn_camera, :spawn_drawing, :pin_objects, :spawn_emoji, :fly]
  @special_actions [:update_hub, :update_roles, :close_hub, :embed_hub, :kick_users, :mute_users, :amplify_audio]

  # Always deny access to non-enterable hubs
  def can?(%Ret.OAuthProvider{}, :join_hub, %Ret.Hub{entry_mode: :deny}), do: false

  # OAuthProvider users cannot perform special actions
  def can?(%Ret.OAuthProvider{}, action, %Ret.Hub{}) when action in @special_actions,
    do: false

  def can?(%Ret.OAuthProvider{} = oauth_provider, :join_hub, %Ret.Hub{hub_bindings: hub_bindings})
      when hub_bindings |> length > 0 do
    hub_bindings |> Enum.any?(&(oauth_provider |> Ret.HubBinding.member_of_channel?(&1)))
  end

  # Object permissions for OAuthProvider users are based on member permission settings
  def can?(%Ret.OAuthProvider{} = oauth_provider, action, %Ret.Hub{hub_bindings: hub_bindings} = hub)
      when action in @object_actions do
    is_member = hub_bindings |> Enum.any?(&(oauth_provider |> Ret.HubBinding.member_of_channel?(&1)))
    is_member and hub |> Hub.has_member_permission?(action)
  end

  def can?(_, :create_hub, _),
    do: !AppConfig.get_cached_config_value("features|disable_room_creation")

  def can?(_, _, _), do: false
end

# Permissions for app tokens and un-authenticated clients
defimpl Canada.Can, for: Atom do
  @allowed_app_token_actions [
    :get_rooms_created_by,
    :get_favorite_rooms_of,
    :get_public_rooms,
    :create_hub,
    :update_hub
  ]
  def can?(:reticulum_app_token, action, _) when action in @allowed_app_token_actions do
    true
  end

  # Bound hubs - Always prevent embedding and role assignment (since it's dictated by binding)
  def can?(:reticulum_app_token, action, %Ret.Hub{hub_bindings: hub_bindings})
      when length(hub_bindings) > 0 and action in [:embed_hub, :update_roles],
      do: false

  # Allow app tokens to act like owners/creators if the room has no bindings
  def can?(:reticulum_app_token, action, %Ret.Hub{})
      when action in [:embed_hub, :update_roles],
      do: true

  def can?(:reticulum_app_token, _, _), do: false

  alias Ret.{AppConfig, Hub}

  # Always deny access to non-enterable hubs
  def can?(_, :join_hub, %Ret.Hub{entry_mode: :deny}), do: false

  # Anyone can join an unbound hub as long as accounts aren't required
  def can?(_, :join_hub, %Ret.Hub{hub_bindings: []}),
    do: !AppConfig.get_cached_config_value("features|require_account_for_join")

  @object_actions [:spawn_and_move_media, :spawn_camera, :spawn_drawing, :pin_objects, :spawn_emoji, :fly]
  # Object permissions for anonymous users are based on member permission settings
  def can?(_account, action, hub) when action in @object_actions do
    hub |> Hub.has_member_permission?(action)
  end

  # Create hubs
  def can?(_, :create_hub, _),
    do: !AppConfig.get_cached_config_value("features|disable_room_creation")

  # Create accounts
  def can?(_, :create_account, _), do: !AppConfig.get_cached_config_value("features|disable_sign_up")

  def can?(_, _, _), do: false
end
