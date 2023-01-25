defmodule RetWeb.Api.V1.AvatarView do
  use RetWeb, :view
  alias Ret.{Avatar, AvatarListing}

  def render("create.json", %{avatar: avatar, account: account}) do
    %{avatars: [render_avatar(avatar, account)]}
  end

  def render("show.json", %{avatar: avatar, account: account}) do
    %{avatars: [render_avatar(avatar, account)]}
  end

  def render("show.json", %{avatars: avatars, account: account}) do
    %{avatars: avatars |> Enum.map(&render_avatar(&1, account))}
  end

  defp render_avatar(%Avatar{} = avatar, account) do
    avatar
    |> common_fields()
    |> Map.merge(%{
      type: "avatar",
      avatar_id: avatar.avatar_sid,
      parent_avatar_id: unless(is_nil(avatar.parent_avatar), do: avatar.parent_avatar.avatar_sid),
      # Only include account id on your own avatars
      account_id:
        account &&
          avatar.account_id == account.account_id &&
          avatar.account_id |> Integer.to_string(),
      allow_remixing: avatar.allow_remixing,
      allow_promotion: avatar.allow_promotion,
      has_listings:
        length(avatar.avatar_listings |> Enum.filter(fn l -> l.state == :active end)) > 0
    })
  end

  defp render_avatar(%AvatarListing{} = listing, _account) do
    listing
    |> common_fields()
    |> Map.merge(%{
      type: "avatar_listing",
      avatar_id: listing.avatar_listing_sid,
      allow_remixing: listing.avatar.allow_remixing,
      allow_promotion: listing.avatar.allow_promotion
    })
  end

  defp common_fields(%t{} = a) when t in [Avatar, AvatarListing] do
    %{
      parent_avatar_listing_id:
        unless(is_nil(a.parent_avatar_listing), do: a.parent_avatar_listing.avatar_listing_sid),
      name: a.name,
      description: a.description,
      attributions: if(is_nil(a.attributions), do: %{}, else: a.attributions),
      gltf_url: a |> Avatar.gltf_url(),
      base_gltf_url: a |> Avatar.base_gltf_url(),
      files:
        for col <- Avatar.file_columns(), into: %{} do
          key = col |> Atom.to_string() |> String.replace_suffix("_owned_file", "")
          {key, a |> Avatar.file_url_or_nil(col)}
        end
    }
  end
end
