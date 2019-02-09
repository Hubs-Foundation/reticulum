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
      gltf_url: avatar.gltf_owned_file |> OwnedFile.uri_for() |> URI.to_string(),
      bin_url: avatar.bin_owned_file |> OwnedFile.uri_for() |> URI.to_string(),
      url: avatar |> url_for_avatar()
    }
  end
end
