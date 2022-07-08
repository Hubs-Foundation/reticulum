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

  # https://www.khronos.org/registry/glTF/specs/2.0/glTF-2.0.html#glb-file-format-specification
  @glb_header_byte_count 20
  @glb_byte_boundary 4
  @glb_header "glTF"
  @glb_version <<2::little-integer-32>>
  @glb_json_type "JSON"
  @glb_padding " "
  def replace_in_glb(glb_stream, search_string, replacement_string) do
    {header_bytes, remaining_stream} = take_bytes(glb_stream, @glb_header_byte_count)

    @glb_header <>
      @glb_version <>
      <<old_glb_length::little-integer-32>> <>
      <<old_json_length::little-integer-32>> <>
      @glb_json_type = header_bytes

    {old_json, remaining_stream} = take_bytes(remaining_stream, old_json_length)

    trimmed_old_json = String.trim_trailing(old_json, @glb_padding)
    new_json = String.replace(trimmed_old_json, search_string, replacement_string)
    new_json_length = ceil(String.length(new_json) / @glb_byte_boundary) * @glb_byte_boundary
    new_padded_json = String.pad_trailing(new_json, new_json_length, @glb_padding)
    new_glb_length = old_glb_length - old_json_length + new_json_length

    new_bytes =
      @glb_header <>
        @glb_version <>
        <<new_glb_length::little-integer-32>> <>
        <<new_json_length::little-integer-32>> <>
        @glb_json_type <>
        new_padded_json

    {Stream.concat([new_bytes], remaining_stream), new_glb_length}
  end

  def take_bytes(chunked_byte_stream, desired_byte_count) do
    {acc_bytes, bytes_size, chunk_count} =
      Enum.reduce_while(
        chunked_byte_stream,
        {<<>>, 0, 0},
        fn chunk, {acc_bytes, bytes_size, chunk_count} = acc ->
          if bytes_size < desired_byte_count do
            {:cont, {acc_bytes <> chunk, bytes_size + byte_size(chunk), chunk_count + 1}}
          else
            {:halt, acc}
          end
        end
      )

    bytes = :binary.part(acc_bytes, 0, desired_byte_count)
    remaining_stream = Stream.drop(chunked_byte_stream, chunk_count)
    remaining_count = bytes_size - desired_byte_count

    if remaining_count == 0 do
      {bytes, remaining_stream}
    else
      remaining_bytes = :binary.part(acc_bytes, bytes_size, -remaining_count)
      {bytes, Stream.concat([remaining_bytes], remaining_stream)}
    end
  end
end
