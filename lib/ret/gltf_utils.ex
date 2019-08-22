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

  def materials_for_node(gltf, node) do
    with mesh_idx when not is_nil(mesh_idx) <- node["mesh"],
         primitives <- get_in(gltf, ["meshes", Access.at(node["mesh"]), "primitives"]) do
      for prim <- primitives, not is_nil(prim["material"]), do: prim["material"]
    else
      _ -> []
    end
  end

  def with_buffer_override(gltf, bin_file) do
    gltf
    |> Map.put("buffers", [
      %{
        "uri" => bin_file |> OwnedFile.uri_for() |> URI.to_string(),
        "byteLength" => bin_file.content_length
      }
    ])
  end

  def with_default_material_override(gltf, image_files) do
    gltf |> with_material_override("Bot_PBS", image_files)
  end

  def with_material_override(gltf, nil, _image_files) do
    gltf
  end

  def with_material_override(gltf, mat_name, image_files) do
    mat_index = gltf["materials"] |> Enum.find_index(&(&1["name"] == mat_name))
    material = gltf |> get_in(["materials", Access.at(mat_index)])

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
        "uri" => file |> OwnedFile.uri_for() |> URI.to_string(),
        "mimeType" => file.content_type
      })
    end)
  end
end
