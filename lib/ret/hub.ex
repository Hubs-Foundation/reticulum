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
  import Ecto.Query

  alias Ret.{Account, Hub, Repo, WebPushSubscription, RoomAssigner}
  alias Ret.Hub.{HubSlug}

  use Bitwise

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
    has_many(:web_push_subscriptions, Ret.WebPushSubscription, foreign_key: :hub_id)
    belongs_to(:account, Ret.Account, references: :account_id)

    timestamps()
  end

  def get_by_entry_code_string(entry_code_string) when is_binary(entry_code_string) do
    case Integer.parse(entry_code_string) do
      {entry_code, _} -> Hub |> Repo.get_by(entry_code: entry_code)
      _ -> nil
    end
  end

  def changeset(%Hub{} = hub, scene, attrs) do
    hub
    |> cast(attrs, [:default_environment_gltf_bundle_url])
    |> add_name_to_changeset(attrs)
    |> add_hub_sid_to_changeset
    |> add_entry_code_to_changeset
    |> unique_constraint(:hub_sid)
    |> unique_constraint(:entry_code)
    |> put_assoc(:scene, scene)
    |> HubSlug.maybe_generate_slug()
    |> HubSlug.unique_constraint()
  end

  def changeset_for_new_name(%Hub{} = hub, attrs) do
    hub
    |> Ecto.Changeset.change()
    |> add_name_to_changeset(attrs)
  end

  defp add_name_to_changeset(changeset, attrs) do
    changeset
    |> cast(attrs, [:name])
    |> validate_length(:name, min: 4, max: 64)
    |> validate_format(:name, ~r/^[A-Za-z0-9-':"!@#$%^&*(),.?~ ]+$/)
  end

  def changeset_for_new_seen_occupant_count(%Hub{} = hub, occupant_count) do
    new_max_occupant_count = max(hub.max_occupant_count, occupant_count)

    hub
    |> cast(%{max_occupant_count: new_max_occupant_count}, [:max_occupant_count])
    |> validate_required([:max_occupant_count])
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
    changeset |> put_assoc(:account, account)
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

  def owns?(%Account{} = account, %Hub{} = hub) do
    account.account_id == hub.account_id
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
end
