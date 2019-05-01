defmodule RetWeb.Api.V1.AvatarView do
  use RetWeb, :view
  alias Ret.{Avatar, OwnedFile}

  def render("create.json", %{avatar: avatar}) do
    %{avatars: [render_avatar(avatar)]}
  end

  def render("show.json", %{avatar: avatar}) do
    %{avatars: [render_avatar(avatar)]}
  end

  def render_avatar(avatar) do
    version = avatar.updated_at |> NaiveDateTime.to_erl |> :calendar.datetime_to_gregorian_seconds
    %{
      avatar_id: avatar.avatar_sid,
      parent_avatar_id: unless(is_nil(avatar.parent_avatar), do: avatar.parent_avatar.avatar_sid),
      name: avatar.name,
      description: avatar.description,
      attributions: if(is_nil(avatar.attributions), do: [], else: avatar.attributions),
      allow_remixing: avatar.allow_remixing,
      allow_promotion: avatar.allow_promotion,
      gltf_url: avatar |> Avatar.gltf_url,
      base_gltf_url: avatar |> Avatar.base_gltf_url,
      files:
        for col <- Avatar.file_columns(), into: %{} do
          key = col |> Atom.to_string() |> String.replace_suffix("_owned_file", "")
          {key, avatar |> Avatar.file_url_or_nil(col)}
        end
    }
  end
end
