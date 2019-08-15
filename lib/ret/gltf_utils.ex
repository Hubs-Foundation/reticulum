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

  def reduce(%{"children" => children} = node, {nodes, acc}, fun) do
    acc = fun.(node, acc)
    children |> Enum.map(&Enum.at(nodes, &1)) |> Enum.reduce({nodes, acc}, &reduce(&1, &2, fun))
  end

  def reduce(node, {nodes, acc}, fun) do
    {nodes, fun.(node, acc)}
  end

  def reduce(%{"scenes" => scenes, "scene" => scene, "nodes" => nodes} = gltf, acc, fun) do
    {nodes, acc} =
      List.first(scenes)["nodes"]
      |> Enum.map(&Enum.at(nodes, &1))
      |> Enum.reduce({nodes, acc}, &reduce(&1, &2, fun))

    acc
  end

  @primary_material_name "Bot_PBS"
  def with_default_material_override(gltf, image_files) do
    material_to_replace =
      case gltf["materials"] |> Enum.find_index(&(&1["name"] == @primary_material_name)) do
        nil ->
          # TODO this currently traverses the whole GLTF, and should early out instead
          first_material =
            gltf
            |> reduce([], &(&2 ++ materials_for_node(gltf, &1)))
            |> List.first()
        idx ->
          idx

      end

    gltf |> with_material_override(material_to_replace, image_files)
  end

  def with_material_override(gltf, nil, _image_files) do
    gltf
  end

  def with_material_override(gltf, mat_index, image_files) do
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
