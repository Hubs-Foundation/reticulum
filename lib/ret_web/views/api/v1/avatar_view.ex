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
    %{avatars: [render_avatar(avatar)]}
  end

  defp file_url_or_nil(avatar, column) do
    case avatar |> Map.get(column) do
      nil -> nil
      owned_file -> owned_file |> OwnedFile.uri_for() |> URI.to_string()
    end
  end

  def render_avatar(avatar) do
    %{
      avatar_id: avatar.avatar_sid,
      parent_avatar_id: unless(is_nil(avatar.parent_avatar), do: avatar.parent_avatar.avatar_sid),
      name: avatar.name,
      description: avatar.description,
      attributions: if(is_nil(avatar.attributions), do: [], else: avatar.attributions),
      allow_remixing: avatar.allow_remixing,
      allow_promotion: avatar.allow_promotion,
      files: %{
        gltf: avatar |> file_url_or_nil(:gltf_owned_file),
        bin: avatar |> file_url_or_nil(:bin_owned_file),
        base_map: avatar |> file_url_or_nil(:base_map_owned_file),
        emissive_map: avatar |> file_url_or_nil(:emissive_map_owned_file),
        normal_map: avatar |> file_url_or_nil(:normal_map_owned_file),
        ao_metalic_roughness_map: avatar |> file_url_or_nil(:ao_metalic_roughness_map),
      }
    }
  end
end
