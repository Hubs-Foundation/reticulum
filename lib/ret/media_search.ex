defmodule Ret.MediaSearchQuery do
  @enforce_keys [:api]
  defstruct [:api, :user]
end

defmodule Ret.MediaSearch do
  import Ret.HttpUtils

  def search(%Ret.MediaSearchQuery{api: "sketchfab", user: user}) do
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
          |> Enum.map(&sketchfab_api_result_to_media_result/1)
      end
    else
      _ -> %{}
    end
  end

  defp sketchfab_api_result_to_media_result(result) do
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
