defmodule Ret.GLTFUtils do
  alias Ret.{OwnedFile}

  @texture_paths %{
    base_map_owned_file: [["pbrMetallicRoughness", "baseColorTexture"]],
    emissive_map_owned_file: [["emissiveTexture"]],
    normal_map_owned_file: [["normalTexture"]],
    orm_map_owned_file: [
      ["pbrMetallicRoughness", "metallicRoughnessTexture"],
      ["occlusionTexture"]
    ]
  }

  def with_buffer(gltf, bin_file) do
    gltf
    |> Map.put("buffers", [
      %{
        uri: bin_file |> OwnedFile.uri_for() |> URI.to_string()
      }
    ])
  end

  def with_material(gltf, name, image_files) do
    case gltf["materials"] |> Enum.find(&(&1["name"] == name)) do
      nil ->
        gltf

      material ->
        image_files
        |> Enum.filter(fn {_, v} -> v end)
        |> Enum.flat_map(fn {col, file} ->
          Enum.map(@texture_paths[col], fn path ->
            texture_index = material |> get_in(path ++ ["index"])
            image_index = gltf |> get_in(["textures", Access.at(texture_index), "source"])
            {image_index, file}
          end)
        end)
        |> Enum.reduce(gltf, fn {index, file}, gltf ->
          gltf
          |> put_in(["images", Access.at(index)], %{
            uri: file |> OwnedFile.uri_for() |> URI.to_string(),
            mimeType: file.content_type
          })
        end)
    end
  end
end
