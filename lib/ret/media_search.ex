defmodule Ret.MediaSearchQuery do
  @enforce_keys [:source]
  defstruct [:source, :user, page: 1, page_size: 20]
end

defmodule Ret.MediaSearchResult do
  @enforce_keys [:meta, :entries]
  defstruct [:meta, :entries]
end

defmodule Ret.MediaSearchResultMeta do
  @enforce_keys [:page, :page_size, :total_pages, :total_entries]
  defstruct [:page, :page_size, :total_pages, :total_entries]
end

defmodule Ret.MediaSearch do
  import Ret.HttpUtils
  import Ecto.Query

  alias Ret.{Repo, Scene}

  def search(%Ret.MediaSearchQuery{source: "pending_scenes", page: page, page_size: page_size}) do
    page =
      Scene
      |> where([s], (is_nil(s.reviewed_at) or s.reviewed_at < s.updated_at) and s.allow_promotion)
      |> order_by(:updated_at)
      |> preload([:screenshot_owned_file, :model_owned_file, :scene_owned_file, :account])
      |> Repo.paginate(%{page: page, page_size: page_size})

    %Ret.MediaSearchResult{
      meta: %Ret.MediaSearchResultMeta{
        page: page.page_number,
        page_size: page.page_size,
        total_pages: page.total_pages,
        total_entries: page.total_entries
      },
      entries: page.entries |> Enum.map(&RetWeb.Api.V1.SceneView.render_scene/1) |> Enum.map(&scene_view_to_entry/1)
    }
  end

  def search(%Ret.MediaSearchQuery{source: "sketchfab", user: user}) do
    # TODO sorting, paging
    with api_key when is_binary(api_key) <- resolver_config(:sketchfab_api_key) do
      res =
        "https://api.sketchfab.com/v3/search?type=models&downloadable=true&user=#{user}"
        |> retry_get_until_success([{"Authorization", "Token #{api_key}"}])

      case res do
        :error ->
          :error

        res ->
          res
          |> Map.get(:body)
          |> Poison.decode!()
          |> Map.get("results")
          |> Enum.map(&sketchfab_api_result_to_entry/1)
      end
    else
      _ -> %{}
    end
  end

  defp scene_view_to_entry(scene_view) do
    %{
      id: scene_view[:scene_id],
      type: "scene",
      name: scene_view[:name],
      description: scene_view[:description],
      attributions: scene_view[:attributions],
      images: %{
        preview: scene_view[:screenshot_url]
      }
    }
  end

  defp sketchfab_api_result_to_entry(result) do
    # TODO when missing thumbnails
    %{
      media_url: "https://sketchfab.com/models/#{result["uid"]}",
      images: %{
        preview:
          result["thumbnails"]["images"]
          |> Enum.sort_by(fn x -> -x["size"] end)
          |> Enum.at(0)
          |> Kernel.get_in(["url"])
      }
    }
  end

  defp resolver_config(key) do
    Application.get_env(:ret, Ret.MediaResolver)[key]
  end
end
