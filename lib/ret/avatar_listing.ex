defmodule Ret.AvatarListing.AvatarListingSlug do
  use EctoAutoslugField.Slug, from: :name, to: :slug

  def get_sources(_changeset, _opts) do
    [:avatar_listing_sid, :name]
  end
end

defmodule Ret.AvatarListing do
  use Ecto.Schema
  import Ecto.Changeset

  alias Ret.{AvatarListing, OwnedFile}
  alias AvatarListing.{AvatarListingSlug}

  @schema_prefix "ret0"
  @primary_key {:avatar_listing_id, :id, autogenerate: true}

  schema "avatar_listings" do
    field(:avatar_listing_sid, :string)
    field(:slug, AvatarListingSlug.Type)
    field(:order, :integer)
    field(:state, AvatarListing.State)
    field(:tags, :map)
    belongs_to(:avatar, Ret.Avatar, references: :avatar_id)
    timestamps()

    # Properties cloned from avatars
    field(:name, :string)
    field(:description, :string)
    field(:attributions, :map)

    has_one(:account, through: [:avatar, :account])
    belongs_to(:parent_avatar_listing, AvatarListing, references: :avatar_listing_id)

    belongs_to(:gltf_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:bin_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:thumbnail_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)

    belongs_to(:base_map_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:emissive_map_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:normal_map_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
    belongs_to(:orm_map_owned_file, OwnedFile, references: :owned_file_id, on_replace: :nilify)
  end

  def changeset_for_listing_for_avatar(
        %AvatarListing{} = listing,
        avatar,
        params \\ %{}
      ) do
    listing
    |> cast(params, [:name, :description, :order, :tags])
    |> maybe_add_avatar_listing_sid_to_changeset
    |> unique_constraint(:avatar_listing_sid)
    |> put_assoc(:avatar, avatar)
    |> put_change(:name, params[:name] || avatar.name)
    |> put_change(:description, params[:description] || avatar.description)
    |> put_change(:attributions, avatar.attributions)
    |> put_change(:parent_avatar_listing_id, avatar.parent_avatar_listing_id)
    |> put_change(:gltf_owned_file_id, avatar.gltf_owned_file_id)
    |> put_change(:bin_owned_file_id, avatar.bin_owned_file_id)
    |> put_change(:thumbnail_owned_file_id, avatar.thumbnail_owned_file_id)
    |> put_change(:base_map_owned_file_id, avatar.base_map_owned_file_id)
    |> put_change(:emissive_map_owned_file_id, avatar.emissive_map_owned_file_id)
    |> put_change(:normal_map_owned_file_id, avatar.normal_map_owned_file_id)
    |> put_change(:orm_map_owned_file_id, avatar.orm_map_owned_file_id)
    |> AvatarListingSlug.maybe_generate_slug()
    |> AvatarListingSlug.unique_constraint()
  end

  defp maybe_add_avatar_listing_sid_to_changeset(changeset) do
    avatar_listing_sid = changeset |> get_field(:avatar_listing_sid) || Ret.Sids.generate_sid()
    put_change(changeset, :avatar_listing_sid, "#{avatar_listing_sid}")
  end
end
