defmodule Ret.GLTFUtilsTest do
  use Ret.DataCase
  alias Ret.{GLTFUtils, OwnedFile, Storage}
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

  @original_file "test/fixtures/test.glb"
  @replaced_file "test/fixtures/replaced.glb"
  @reversed_file "test/fixtures/reversed.glb"
  @old_url "https://hubs.local"
  @new_url "https://new-domain.local"
  test "encrypted replace" do
    # This test uses store_and_replace_in_glb_file so that the entire storage flow is exercised, including encryption,
    # decryption, and fetching.

    store_and_replace_in_glb_file(
      @original_file,
      "non-existent-string",
      "foo",
      @replaced_file
    )

    assert sha1sum(@original_file) == sha1sum(@replaced_file)

    store_and_replace_in_glb_file(
      @original_file,
      @old_url,
      @new_url,
      @replaced_file
    )

    assert sha1sum(@original_file) != sha1sum(@replaced_file)
    assert File.read!(@original_file) |> String.contains?(@old_url)
    refute File.read!(@replaced_file) |> String.contains?(@old_url)
    assert File.read!(@replaced_file) |> String.contains?(@new_url)

    store_and_replace_in_glb_file(
      @replaced_file,
      @new_url,
      @old_url,
      @reversed_file
    )

    assert sha1sum(@original_file) == sha1sum(@reversed_file)

    File.rm!(@replaced_file)
    File.rm!(@reversed_file)
  end

  defp store_and_replace_in_glb_file(input_file, search_string, replacement_string, output_file) do
    account = create_random_account()

    key = SecureRandom.hex()
    promotion_token = SecureRandom.hex()
    {:ok, uuid} = Storage.store(input_file, "model/gltf-binary", key, promotion_token)
    {:ok, owned_file} = Storage.promote(uuid, key, promotion_token, account)

    {:ok, replaced_owned_file} =
      Storage.duplicate_and_transform(owned_file, account, fn glb_stream, _total_bytes ->
        GLTFUtils.replace_in_glb(glb_stream, search_string, replacement_string)
      end)

    {:ok, _meta, output_stream} = Storage.fetch(replaced_owned_file)

    output_stream
    |> Stream.into(File.stream!(output_file))
    |> Stream.run()
  end

  defp sha1sum(file_path) do
    {output, 0} = System.cmd("sha1sum", [file_path])
    String.split(output) |> Enum.at(0)
  end
end
