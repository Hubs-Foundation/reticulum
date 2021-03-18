defmodule Ret.SketchfabTest do
  use Ret.DataCase

  import Ret.MediaSearch, only: [sketchfab_search: 1]

  alias Ret.{MediaResolver, CachedFile, MediaSearchResult, Storage}

  setup_all do
    {:ok, url} = sketchfab_url_for("cube")
    model_id = model_id_for(URI.parse(url))
    cache_key = "sketchfab-#{model_id}-0"

    %{
      api_key: Application.get_env(:ret, MediaResolver)[:sketchfab_api_key],
      cube: %{
        url: url,
        model_id: model_id,
        cache_key: cache_key
      }
    }
  end

  @tag dev_only: true
  test "Can search Sketchfab models", %{} do
    {:ok, _url} = sketchfab_url_for("cube")
  end

  @tag dev_only: true
  test "Can download Sketchfab models", %{api_key: api_key, cube: %{model_id: model_id}} do
    {:ok, path} = Temp.path()

    try do
      case MediaResolver.download_sketchfab_model_to_path(%{
             model_id: model_id,
             api_key: api_key,
             path: path
           }) do
        {:ok, _} -> nil
        _ -> flunk("Failed to download sketchfab model.")
      end
    after
      File.rm_rf(path)
    end
  end

  @tag dev_only: true
  test "Sketchfab models are cached", %{
    api_key: api_key,
    cube: %{model_id: model_id, cache_key: cache_key}
  } do
    {:ok, uri} =
      CachedFile.fetch(
        cache_key,
        fn path ->
          MediaResolver.download_sketchfab_model_to_path(%{
            model_id: model_id,
            api_key: api_key,
            path: path
          })
        end
      )

    %CachedFile{file_uuid: file_uuid, file_content_type: file_content_type, file_key: file_key} =
      CachedFile |> where(cache_key: ^cache_key) |> Repo.one()

    assert uri === Storage.uri_for(file_uuid, file_content_type, file_key)
  end

  defp sketchfab_url_for(search_term) when is_binary(search_term) do
    query =
      URI.encode_query(
        type: :models,
        downloadable: true,
        count: 1,
        max_face_count: 10_000,
        max_filesizes: "gltf:#{16 * 1024}",
        processing_status: :succeeded,
        cursor: nil,
        q: search_term
      )

    case sketchfab_search(query) do
      {:commit, %MediaSearchResult{entries: entries}} ->
        %{url: url} = hd(entries)
        {:ok, url}

      _ ->
        {:error, "Search failed"}
    end
  end

  defp model_id_for(%URI{path: "/models/" <> model_id}), do: model_id
  defp model_id_for(%URI{path: "/3d-models/" <> s}), do: s |> String.split("-") |> Enum.at(-1)
end
