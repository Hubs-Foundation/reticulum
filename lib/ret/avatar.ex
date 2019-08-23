defmodule Ret.Avatar.AvatarSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug, always_change: true

  def get_sources(_changeset, _opts) do
    [:avatar_sid, :name]
  end
end

defmodule Ret.Avatar do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Ret.{Avatar, AvatarListing, Repo, OwnedFile, Account, Sids, Storage}
  alias Ret.Avatar.{AvatarSlug}

  @schema_prefix "ret0"
  @primary_key {:avatar_id, :id, autogenerate: true}

  @image_columns [
    :base_map_owned_file,
    :emissive_map_owned_file,
    :normal_map_owned_file,
    :orm_map_owned_file
  ]
  @file_columns [:gltf_owned_file, :bin_owned_file, :thumbnail_owned_file] ++ @image_columns

  def image_columns, do: @image_columns
  def file_columns, do: @file_columns

  schema "avatars" do
    field(:avatar_sid, :string)
    field(:slug, AvatarSlug.Type)

    field(:name, :string)
    field(:description, :string)
    field(:attributions, :map)

    belongs_to(:account, Account, references: :account_id)
    belongs_to(:parent_avatar, Avatar, references: :avatar_id, on_replace: :nilify)
    belongs_to(:parent_avatar_listing, AvatarListing, references: :avatar_listing_id, on_replace: :nilify)

    has_many(:avatar_listings, AvatarListing, foreign_key: :avatar_id, references: :avatar_id, on_replace: :nilify)

    field(:allow_remixing, :boolean)
    field(:allow_promotion, :boolean)

    belongs_to(:gltf_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:bin_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:thumbnail_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)

    belongs_to(:base_map_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:emissive_map_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:normal_map_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:orm_map_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)

    field(:state, Avatar.State)

    field(:reviewed_at, :utc_datetime)
    timestamps()
  end

  def load_parents(avatar, preload_fields \\ [])

  def load_parents(%AvatarListing{parent_avatar_listing: nil} = avatar, preload_fields),
    do: avatar |> Repo.preload(preload_fields)

  def load_parents(%Avatar{parent_avatar_listing: nil, parent_avatar: nil} = avatar, preload_fields),
    do: avatar |> Repo.preload(preload_fields)

  def load_parents(%AvatarListing{} = avatar, preload_fields) do
    avatar
    |> Repo.preload([:parent_avatar_listing] ++ preload_fields)
    |> Map.update!(
      :parent_avatar_listing,
      &Avatar.load_parents(&1, preload_fields)
    )
  end

  def load_parents(%Avatar{parent_avatar_listing: nil, parent_avatar: parent} = avatar, preload_fields) do
    avatar
    |> Repo.preload([:parent_avatar] ++ preload_fields)
    |> Map.update!(
      :parent_avatar,
      &Avatar.load_parents(&1, preload_fields)
    )
  end

  def load_parents(%Avatar{} = avatar, preload_fields) do
    avatar
    |> Repo.preload([:parent_avatar_listing, :parent_avatar] ++ preload_fields)
    |> Map.update!(
      :parent_avatar_listing,
      &Avatar.load_parents(&1, preload_fields)
    )
  end

  def load_parents(nil, _preload_fields), do: nil

  defp avatar_to_collapsed_files(%AvatarListing{parent_avatar_listing: nil} = avatar),
    do: avatar |> Map.take(@file_columns)

  defp avatar_to_collapsed_files(%Avatar{parent_avatar_listing: nil, parent_avatar: nil} = avatar),
    do: avatar |> Map.take(@file_columns)

  defp avatar_to_collapsed_files(%AvatarListing{parent_avatar_listing: parent_listing} = avatar) do
    parent_listing
    |> avatar_to_collapsed_files
    |> Map.merge(avatar |> Map.take(@file_columns), fn
      _k, v1, nil -> v1
      _k, _v1, v2 -> v2
    end)
  end

  defp avatar_to_collapsed_files(%Avatar{parent_avatar_listing: parent_listing, parent_avatar: parent} = avatar) do
    (parent_listing || parent)
    |> avatar_to_collapsed_files
    |> Map.merge(avatar |> Map.take(@file_columns), fn
      _k, v1, nil -> v1
      _k, _v1, v2 -> v2
    end)
  end

  def collapsed_files(%t{} = avatar) when t in [Avatar, AvatarListing] do
    # TODO we ideally don't need to be featching the OwnedFiles until after we collapse them
    avatar
    |> Avatar.load_parents(@file_columns)
    |> avatar_to_collapsed_files()
  end

  def version(%t{} = a) when t in [Avatar, AvatarListing],
    do: a.updated_at |> NaiveDateTime.to_erl() |> :calendar.datetime_to_gregorian_seconds()

  def url(%Avatar{} = avatar), do: "#{RetWeb.Endpoint.url()}/avatars/#{avatar.avatar_sid}"
  def url(%AvatarListing{} = avatar), do: "#{RetWeb.Endpoint.url()}/avatars/#{avatar.avatar_listing_sid}"

  defp api_base_url(%Avatar{} = avatar), do: "#{RetWeb.Endpoint.url()}/api/v1/avatars/#{avatar.avatar_sid}"

  defp api_base_url(%AvatarListing{} = avatar),
    do: "#{RetWeb.Endpoint.url()}/api/v1/avatars/#{avatar.avatar_listing_sid}"

  def gltf_url(%t{} = a) when t in [Avatar, AvatarListing], do: "#{api_base_url(a)}/avatar.gltf?v=#{Avatar.version(a)}"

  def base_gltf_url(%t{} = a) when t in [Avatar, AvatarListing],
    do: "#{api_base_url(a)}/base.gltf?v=#{Avatar.version(a)}"

  def file_url_or_nil(%t{} = a, column) when t in [Avatar, AvatarListing] do
    case a |> Map.get(column) do
      nil -> nil
      owned_file -> owned_file |> OwnedFile.uri_for() |> URI.to_string()
    end
  end

  def avatar_or_avatar_listing_by_sid(sid) do
    Avatar |> Repo.get_by(avatar_sid: sid) |> Repo.preload(:parent_avatar) ||
      AvatarListing |> Repo.get_by(avatar_listing_sid: sid) |> Repo.preload(:avatar)
  end

  def new_avatar_from_parent_sid(parent_sid, account) when not is_nil(parent_sid) and parent_sid != "" do
    with parent <-
           parent_sid
           |> avatar_or_avatar_listing_by_sid()
           |> Repo.preload([:thumbnail_owned_file]),
         thumbnail when not is_nil(thumbnail) <- parent.thumbnail_owned_file,
         {:ok, new_thumbnail} <- Storage.duplicate(thumbnail, account) do
      %Avatar{
        thumbnail_owned_file: new_thumbnail
      }
    else
      _ -> %Avatar{}
    end
  end

  def new_avatar_from_parent_sid(_parent_avatar_sid, _account) do
    %Avatar{}
  end

  def delete_avatar_and_delist_listings(avatar) do
    Ecto.Multi.new()
    |> Ecto.Multi.update_all(
      :update_all,
      from(l in AvatarListing,
        join: a in Avatar,
        on: l.avatar_id == a.avatar_id,
        where: l.avatar_id == ^avatar.avatar_id and l.account_id == ^avatar.account_id
      ),
      set: [state: :delisted, avatar_id: nil]
    )
    |> Ecto.Multi.delete(:delete, avatar)
    |> Repo.transaction()
  end

  @doc false
  def changeset(
        %Avatar{} = avatar,
        account,
        owned_files_map,
        parent_avatar,
        parent_avatar_listing,
        attrs \\ %{}
      ) do
    avatar
    |> cast(attrs, [:name, :description, :attributions, :allow_remixing, :allow_promotion])
    |> validate_required([])
    |> maybe_add_avatar_sid_to_changeset
    |> unique_constraint(:avatar_sid)
    |> put_change(:account_id, account.account_id)
    |> put_assoc(:parent_avatar, parent_avatar)
    |> put_assoc(:parent_avatar_listing, parent_avatar_listing)
    |> put_owned_files(owned_files_map)
    |> AvatarSlug.maybe_generate_slug()
  end

  defp put_owned_files(in_changeset, owned_files_map) do
    Enum.reduce(owned_files_map, in_changeset, fn
      {key, :remove}, changes ->
        changes |> put_assoc(key, nil)

      {key, file}, changes ->
        changes |> put_assoc(key, file)
    end)
  end

  defp maybe_add_avatar_sid_to_changeset(changeset) do
    avatar_sid = changeset |> get_field(:avatar_sid) || Sids.generate_sid()
    put_change(changeset, :avatar_sid, avatar_sid)
  end
end
