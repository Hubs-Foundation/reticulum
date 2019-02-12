defmodule RetWeb.Api.V1.AvatarView do
  use RetWeb, :view
  alias Ret.OwnedFile

  defp url_for_avatar(avatar) do
    "#{RetWeb.Endpoint.url()}/avatars/#{avatar.avatar_sid}/#{avatar.slug}"
  end

  def render("create.json", %{avatar: avatar}) do
    %{avatars: [render_avatar(avatar)]}
  end

  def render("show.json", %{avatar: avatar}) do
    %{scenes: [render_avatar(avatar)]}
  end

  def render_avatar(avatar) do
    %{
      avatar_id: avatar.avatar_sid,
      name: avatar.name,
      description: avatar.description,
      attributions: avatar.attributions,
      url: avatar |> url_for_avatar(),
      parent_avatar_id: avatar.parent_avatar.avatar_sid
    }
  end
end
