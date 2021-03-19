defmodule Ret.GooglePolyTest do
  use Ret.DataCase
  use Retry
  import Ret.HttpUtils

  import Ret.MediaSearch, only: [sketchfab_search: 1]

  alias Ret.{MediaResolver, MediaResolverQuery, CachedFile, MediaSearchResult, Storage}

  test "Can search google poly" do
    IO.puts("OK test is running")

    query = %MediaResolverQuery{
      url: "https://poly.google.com/view/fbDxapxkwY9" |> URI.parse(),
      supports_webm: true,
      quality: :high,
      version: 1
    }

    resolve_non_video(query, "google.com")
  end

  defp resolve_non_video(
         %MediaResolverQuery{url: %URI{host: "poly.google.com", path: "/view/" <> asset_id} = uri},
         "google.com"
       ) do
    # IO.inspect("https://poly.googleapis.com/v1/assets/#{asset_id}?key=#{poly_api_key()}")

    [uri, meta] =
      with api_key when is_binary(api_key) <- poly_api_key() do
        # "https://poly.googleapis.com/v1/assets/#{asset_id}?key=#{api_key}"
        # |> retry_get_until_success([{"Authorization", "Token #{api_key}"}], 15_000, 15_000)
        # |> Map.get(:body)
        # |> Poison.decode!()
        resp = Path.join(__DIR__, "poly_api_response.json")
        {:ok, payload} = File.read(Path.join(__DIR__, "poly_api_response.json"))

        payload = payload |> Poison.decode!()

        meta =
          %{expected_content_type: "model/gltf"}
          |> Map.put(:name, payload["displayName"])
          |> Map.put(:author, payload["authorName"])
          |> Map.put(:license, payload["license"])

        formats = payload |> Map.get("formats")

        gltf2_info =
          Enum.find(formats, &(&1["formatType"] == "GLTF2")) || Enum.find(formats, &(&1["formatType"] == "GLTF"))

        {:ok, path} = Temp.path()
        download_poly_model_to_path(gltf2_info, path)

        # TODO: The poly model contains links (like)
        # [gltf_uri, meta]
        ["foo", "bar"]
      else
        _err -> [uri, nil]
      end

    # IO.inspect({:commit, uri, meta})
    # {:commit, uri |> resolved(meta)}
  end

  def download_poly_model_to_path(gltf2_info, path) do
    gltf_url =
      gltf2_info
      |> Kernel.get_in(["root", "url"])

    gltf_relative_path =
      (gltf2_info
       |> Kernel.get_in(["root", "relativePath"])) <>
        ".glb"

    bin_url =
      gltf2_info
      |> Kernel.get_in(["resources", Access.at(0), "url"])

    bin_relative_path =
      gltf2_info
      |> Kernel.get_in(["resources", Access.at(0), "relativePath"])

    IO.inspect({gltf_url, gltf_relative_path, bin_url, bin_relative_path, path})
    File.mkdir_p(path)
    Download.from(gltf_url, path: Path.join(path, gltf_relative_path))
    Download.from(bin_url, path: Path.join(path, bin_relative_path))
    {:ok, %{content_type: "model/gltf"}}
  end

  defp poly_api_key do
    Application.get_env(:ret, MediaResolver)[:google_poly_api_key]
  end
end
