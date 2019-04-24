defmodule Ret.Avatar.AvatarSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug

  def get_sources(_changeset, _opts) do
    [:avatar_sid, :name]
  end
end

defmodule Ret.Avatar do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{Avatar, Repo, OwnedFile, Account, Sids}
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
    belongs_to(:parent_avatar, Avatar, references: :avatar_id)

    field(:name, :string)
    field(:description, :string)
    field(:attributions, :map)

    field(:allow_remixing, :boolean)
    field(:allow_promotion, :boolean)
    belongs_to(:account, Account, references: :account_id)

    belongs_to(:gltf_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:bin_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:thumbnail_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)

    belongs_to(:base_map_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)

    belongs_to(:emissive_map_owned_file, OwnedFile,
      references: :owned_file_id,
      on_replace: :nilify
    )

    belongs_to(:normal_map_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:orm_map_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)

    field(:state, Avatar.State)

    timestamps()
  end

  def load_parents(avatar, preload_fields \\ [])

  def load_parents(%Avatar{parent_avatar: nil} = avatar, preload_fields),
    do: avatar |> Repo.preload(preload_fields)

  def load_parents(%Avatar{} = avatar, preload_fields) do
    avatar
    |> Repo.preload([:parent_avatar] ++ preload_fields)
    |> Map.update!(
      :parent_avatar,
      &Avatar.load_parents(&1, preload_fields)
    )
  end

  def load_parents(nil, _preload_fields), do: nil

  defp avatar_to_collapsed_files(%{parent_avatar: nil} = avatar),
    do: avatar |> Map.take(@file_columns)

  defp avatar_to_collapsed_files(%{parent_avatar: parent} = avatar) do
    parent
    |> avatar_to_collapsed_files
    |> Map.merge(avatar |> Map.take(@file_columns), fn
      _k, v1, nil -> v1
      _k, _v1, v2 -> v2
    end)
  end

  def collapsed_files(%Avatar{} = avatar) do
    # TODO we ideally don't need to be featching the OwnedFiles until after we collapse them
    avatar
    |> Avatar.load_parents(@file_columns)
    |> avatar_to_collapsed_files()
  end

  def version(%Avatar{} = avatar) do
    avatar.updated_at |> NaiveDateTime.to_erl |> :calendar.datetime_to_gregorian_seconds
  end

  def url(%Avatar{} = avatar) do
    "#{RetWeb.Endpoint.url()}/api/v1/avatars/#{avatar.avatar_sid}"
  end

  def gltf_url(%Avatar{} = avatar) do
    "#{Avatar.url(avatar)}/avatar.gltf?v=#{Avatar.version(avatar)}"
  end

  def base_gltf_url(%Avatar{} = avatar) do
    "#{Avatar.url(avatar)}/base.gltf?v=#{Avatar.version(avatar)}"
  end

  def file_url_or_nil(%Avatar{} = avatar, column) do
    case avatar |> Map.get(column) do
      nil -> nil
      owned_file -> owned_file |> OwnedFile.uri_for() |> URI.to_string()
    end
  end

  @doc false
  def changeset(
        %Avatar{} = avatar,
        account,
        owned_files_map,
        parent_avatar,
        attrs \\ %{}
      ) do
    avatar
    |> cast(attrs, [:name])
    |> validate_required([])
    |> maybe_add_avatar_sid_to_changeset
    |> unique_constraint(:avatar_sid)
    |> put_assoc(:account, account)
    |> put_assoc(:parent_avatar, parent_avatar)
    |> put_owned_files(owned_files_map)
    |> AvatarSlug.maybe_generate_slug()
    |> AvatarSlug.unique_constraint()
  end

  defp put_owned_files(in_changeset, owned_files_map) do
    Enum.reduce(owned_files_map, in_changeset, fn
      {key, :remove}, changes ->
        changes |> put_assoc(:"#{key}_owned_file", nil)

      {key, file}, changes ->
        changes |> put_assoc(:"#{key}_owned_file", file)
    end)
  end

  defp maybe_add_avatar_sid_to_changeset(changeset) do
    avatar_sid = changeset |> get_field(:avatar_sid) || Sids.generate_sid()
    put_change(changeset, :avatar_sid, avatar_sid)
  end
end
