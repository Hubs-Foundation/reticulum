defmodule Ret.Avatar.AvatarSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug

  def get_sources(_changeset, _opts) do
    [:avatar_sid, :name]
  end
end

defmodule Ret.Avatar do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{Avatar, AvatarListing, Repo, OwnedFile, Account, Sids}
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

  defp avatar_to_collapsed_files(%{parent_avatar: nil, parent_avatar_listing: nil} = avatar),
    do: avatar |> Map.take(@file_columns)

  defp avatar_to_collapsed_files(%{parent_avatar: parent, parent_avatar_listing: parent_listing} = avatar) do
    (parent_listing || parent)
    |> Repo.preload(@file_columns)
    |> Map.take(@file_columns)
    |> Map.merge(avatar |> Map.take(@file_columns), fn
      _k, v1, nil -> v1
      _k, _v1, v2 -> v2
    end)
  end

  defp avatar_listing_to_collapsed_files(%{parent_avatar_listing: nil} = listing),
    do: listing |> Map.take(Avatar.file_columns())

  defp avatar_listing_to_collapsed_files(%{parent_avatar_listing: parent} = listing) do
    parent
    |> Repo.preload(@file_columns)
    |> Map.take(@file_columns)
    |> Map.merge(listing |> Map.take(@file_columns), fn
      _k, v1, nil -> v1
      _k, _v1, v2 -> v2
    end)
  end

  def collapsed_files(%Avatar{} = avatar) do
    avatar
    |> Repo.preload([:parent_avatar, :parent_avatar_listing] ++ @file_columns)
    |> avatar_to_collapsed_files()
  end

  def collapsed_files(%AvatarListing{} = listing) do
    listing |> Repo.preload([:parent_avatar_listing] ++ Avatar.file_columns()) |> avatar_listing_to_collapsed_files()
  end

  def version(%t{} = a) when t in [Avatar, AvatarListing],
    do: a.updated_at |> NaiveDateTime.to_erl() |> :calendar.datetime_to_gregorian_seconds()

  def url(%Avatar{} = avatar), do: "#{RetWeb.Endpoint.url()}/avatars/#{avatar.avatar_sid}"
  def url(%AvatarListing{} = avatar), do: "#{RetWeb.Endpoint.url()}/avatars/#{avatar.avatar_listing_sid}"

  defp api_base_url(%Avatar{} = avatar), do: "#{RetWeb.Endpoint.url()}/api/v1/avatars/#{avatar.avatar_sid}"
  defp api_base_url(%AvatarListing{} = avatar), do: "#{RetWeb.Endpoint.url()}/api/v1/avatars/#{avatar.avatar_listing_sid}"

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
    |> put_assoc(:account, account)
    |> put_assoc(:parent_avatar, parent_avatar)
    |> put_assoc(:parent_avatar_listing, parent_avatar_listing)
    |> put_owned_files(owned_files_map)
    |> AvatarSlug.maybe_generate_slug()
    |> AvatarSlug.unique_constraint()
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
