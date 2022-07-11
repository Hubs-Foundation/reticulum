defmodule Ret.GLTFUtilsTest do
  use Ret.DataCase
  alias Ret.{GLTFUtils, OwnedFile}
  import Ret.TestHelpers

  @sample_gltf %{
    "materials" => [
      %{
        "pbrMetallicRoughness" => %{
          "metallicRoughnessTexture" => %{
            "texCoord" => 0,
            "index" => 2
          },
          "baseColorTexture" => %{
            "texCoord" => 0,
            "index" => 3
          }
        },
        "occlusionTexture" => %{
          "texCoord" => 0,
          "index" => 2
        },
        "normalTexture" => %{
          "texCoord" => 0,
          "index" => 1
        },
        "name" => "Bot_PBS",
        "emissiveTexture" => %{
          "texCoord" => 0,
          "index" => 0
        },
        "emissiveFactor" => [1, 1, 1]
      }
    ],
    "textures" => [
      %{"source" => 3},
      %{"source" => 0},
      %{"source" => 1},
      %{"source" => 2}
    ],
    "images" => [
      %{
        "name" => "Avatar_Normal.png",
        "mimeType" => "image/png",
        "bufferView" => 7
      },
      %{
        "name" => "Avatar_ORM.jpg",
        "mimeType" => "image/png",
        "bufferView" => 8
      },
      %{
        "name" => "Avatar_BaseColor.jpg",
        "mimeType" => "image/png",
        "bufferView" => 9
      },
      %{
        "name" => "Avatar_Emissive.jpg",
        "mimeType" => "image/png",
        "bufferView" => 6
      }
    ],
    "buffers" => []
  }

  @multi_orm_gltf %{
    "materials" => [
      %{
        "pbrMetallicRoughness" => %{
          "metallicRoughnessTexture" => %{
            "texCoord" => 0,
            "index" => 4
          },
          "baseColorTexture" => %{
            "texCoord" => 0,
            "index" => 3
          }
        },
        "occlusionTexture" => %{
          "texCoord" => 0,
          "index" => 2
        },
        "normalTexture" => %{
          "texCoord" => 0,
          "index" => 1
        },
        "name" => "Bot_PBS",
        "emissiveTexture" => %{
          "texCoord" => 0,
          "index" => 0
        },
        "emissiveFactor" => [1, 1, 1]
      }
    ],
    "textures" => [
      %{"source" => 3},
      %{"source" => 0},
      %{"source" => 1},
      %{"source" => 2},
      %{"source" => 4}
    ],
    "images" => [
      %{
        "name" => "Avatar_Normal.png",
        "mimeType" => "image/png",
        "bufferView" => 7
      },
      %{
        "name" => "Avatar_ORM.jpg",
        "mimeType" => "image/png",
        "bufferView" => 8
      },
      %{
        "name" => "Avatar_BaseColor.jpg",
        "mimeType" => "image/png",
        "bufferView" => 9
      },
      %{
        "name" => "Avatar_Emissive.jpg",
        "mimeType" => "image/png",
        "bufferView" => 6
      },
      %{
        "name" => "Avatar_ORM_2.jpg",
        "mimeType" => "image/png",
        "bufferView" => 10
      }
    ],
    "buffers" => []
  }

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  setup _context do
    account = create_random_account()

    %{
      account: account,
      temp_owned_file: generate_temp_owned_file(account)
    }
  end

  test "replaces buffers with bin owned file", %{temp_owned_file: temp_owned_file} do
    input_gltf = @sample_gltf
    output_gltf = input_gltf |> GLTFUtils.with_buffer_override(temp_owned_file)

    bin_url = temp_owned_file |> OwnedFile.uri_for() |> URI.to_string()
    buffers = output_gltf["buffers"]
    buffer = output_gltf |> get_in(["buffers", Access.at(0)])
    assert Enum.count(buffers) == 1
    assert buffer["uri"] == bin_url
    assert buffer["byteLength"] == temp_owned_file.content_length
  end

  test "replace only base texture", %{temp_owned_file: temp_owned_file} do
    input_gltf = @sample_gltf
    output_gltf = input_gltf |> GLTFUtils.with_default_material_override(%{base_map_owned_file: temp_owned_file})

    img_url = temp_owned_file |> OwnedFile.uri_for() |> URI.to_string()
    assert img_url == output_gltf |> get_in(["images", Access.at(2), "uri"])

    for i <- [0, 1, 3], path = ["images", Access.at(i)] do
      assert input_gltf |> get_in(path) == output_gltf |> get_in(path)
    end
  end

  test "replace ORM texture", %{temp_owned_file: temp_owned_file} do
    input_gltf = @sample_gltf
    output_gltf = input_gltf |> GLTFUtils.with_default_material_override(%{orm_map_owned_file: temp_owned_file})

    img_url = temp_owned_file |> OwnedFile.uri_for() |> URI.to_string()
    assert img_url == output_gltf |> get_in(["images", Access.at(1), "uri"])

    for i <- [0, 2, 3], path = ["images", Access.at(i)] do
      assert input_gltf |> get_in(path) == output_gltf |> get_in(path)
    end
  end

  test "replace multiple ORM texture", %{temp_owned_file: temp_owned_file} do
    input_gltf = @multi_orm_gltf
    output_gltf = input_gltf |> GLTFUtils.with_default_material_override(%{orm_map_owned_file: temp_owned_file})

    img_url = temp_owned_file |> OwnedFile.uri_for() |> URI.to_string()
    assert img_url == output_gltf |> get_in(["images", Access.at(1), "uri"])
    assert img_url == output_gltf |> get_in(["images", Access.at(4), "uri"])

    for i <- [0, 2, 3], path = ["images", Access.at(i)] do
      assert input_gltf |> get_in(path) == output_gltf |> get_in(path)
    end
  end

  test "take_bytes" do
    input = ["foobarbazspameggs", "thequickbrownfox", "jumpedoverthelazydog"]

    {bytes, rest} = GLTFUtils.take_bytes(input, 10)
    assert "foobarbazs" == bytes
    assert ["pameggs", "thequickbrownfox", "jumpedoverthelazydog"] == Enum.to_list(rest)

    {bytes, rest} = GLTFUtils.take_bytes(input, 20)
    assert "foobarbazspameggsthe" == bytes
    assert ["quickbrownfox", "jumpedoverthelazydog"] == Enum.to_list(rest)

    {bytes, rest} = GLTFUtils.take_bytes(input, 17)
    assert "foobarbazspameggs" == bytes
    assert ["thequickbrownfox", "jumpedoverthelazydog"] == Enum.to_list(rest)

    {bytes, rest} = GLTFUtils.take_bytes(input, 33)
    assert "foobarbazspameggsthequickbrownfox" == bytes
    assert ["jumpedoverthelazydog"] == Enum.to_list(rest)
  end

  @tag marked: true
  test "replace_in_glb" do
    replace_in_glb_file(
      "test/fixtures/test.glb",
      "https://uploads-prod.reticulum.io",
      "https://foobar",
      "test/fixtures/out.glb"
    )

    replace_in_glb_file(
      "test/fixtures/out.glb",
      "https://foobar",
      "https://uploads-prod.reticulum.io",
      "test/fixtures/reverse.glb"
    )

    refute File.read!("test/fixtures/test.glb") |> String.contains?("https://foobar")
    assert File.read!("test/fixtures/out.glb") |> String.contains?("https://foobar")
    refute File.read!("test/fixtures/reverse.glb") |> String.contains?("https://foobar")

    assert sha1sum("test/fixtures/test.glb") != sha1sum("test/fixtures/out.glb")
    assert sha1sum("test/fixtures/test.glb") == sha1sum("test/fixtures/reverse.glb")

    File.rm!("test/fixtures/out.glb")
    File.rm!("test/fixtures/reverse.glb")
  end

  defp replace_in_glb_file(input_file, search_string, replacement_string, output_file) do
    {output_stream, _output_length} =
      File.stream!(input_file, [], 1024 * 1024)
      |> GLTFUtils.replace_in_glb(search_string, replacement_string)

    output_stream
    |> Stream.into(File.stream!(output_file))
    |> Stream.run()
  end

  defp sha1sum(file_path) do
    {output, 0} = System.cmd("sha1sum", [file_path])
    String.split(output) |> Enum.at(0)
  end
end
