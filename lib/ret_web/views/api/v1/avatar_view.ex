defmodule RetWeb.Api.V1.AvatarView do
  use RetWeb, :view
  alias Ret.{Avatar, AvatarListing}

  def render("create.json", %{avatar: avatar}) do
    %{avatars: [render_avatar(avatar)]}
  end

  def render("show.json", %{avatar: avatar}) do
    %{avatars: [render_avatar(avatar)]}
  end

  def render_avatar(%Avatar{} = a) do
    %{
      avatar_id: a.avatar_sid,
      parent_avatar_id: unless(is_nil(a.parent_avatar), do: a.parent_avatar.avatar_sid),
      parent_avatar_listing_id: unless(is_nil(a.parent_avatar_listing), do: a.parent_avatar_listing.avatar_listing_sid),
      name: a.name,
      description: a.description,
      attributions: if(is_nil(a.attributions), do: %{}, else: a.attributions),
      allow_remixing: a.allow_remixing,
      allow_promotion: a.allow_promotion,
      gltf_url: a |> Avatar.gltf_url(),
      base_gltf_url: a |> Avatar.base_gltf_url(),
      files:
        for col <- Avatar.file_columns(), into: %{} do
          key = col |> Atom.to_string() |> String.replace_suffix("_owned_file", "")
          {key, a |> Avatar.file_url_or_nil(col)}
        end
    }
  end

  def render_avatar(%AvatarListing{} = a) do
    %{
      avatar_id: a.avatar_listing_sid,
      parent_avatar_listing_id: unless(is_nil(a.parent_avatar_listing), do: a.parent_avatar_listing.avatar_listing_sid),
      name: a.name,
      description: a.description,
      attributions: if(is_nil(a.attributions), do: %{}, else: a.attributions),
      allow_remixing: a.avatar.allow_remixing,
      allow_promotion: a.avatar.allow_promotion,
      gltf_url: a |> AvatarListing.gltf_url(),
      base_gltf_url: a |> AvatarListing.base_gltf_url(),
      files:
        for col <- Avatar.file_columns(), into: %{} do
          key = col |> Atom.to_string() |> String.replace_suffix("_owned_file", "")
          {key, a |> AvatarListing.file_url_or_nil(col)}
        end
    }
  end
end
