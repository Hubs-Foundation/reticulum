defmodule Ret.PageOriginWarmer do
  use Cachex.Warmer
  use Retry

  # @pages is a list of { source, page } tuples eg { :hubs, "scene.html" }
  @pages %{
           hubs:
             ~w(index.html whats-new.html hub.html link.html scene.html avatar.html spoke.html discord.html admin.html hub.service.js),
           spoke: ~w(index.html)
         }
         |> Enum.map(fn {k, vs} -> vs |> Enum.map(&{k, &1}) end)
         |> List.flatten()

  def interval, do: :timer.seconds(15)

  def execute(_state) do
    with hubs_page_origin when is_binary(hubs_page_origin) <- module_config(:hubs_page_origin),
         spoke_page_origin when is_binary(spoke_page_origin) <- module_config(:spoke_page_origin) do
      cache_values =
        @pages
        |> Enum.map(fn {source, page} -> Task.async(fn -> page_to_cache_entry(source, page) end) end)
        |> Enum.map(&Task.await(&1, 15000))
        |> Enum.reject(&is_nil/1)

      {:ok, cache_values}
    else
      _ -> {:ok, []}
    end
  end

  defp page_to_cache_entry(source, page) do
    config_key =
      if source == :hubs do
        :hubs_page_origin
      else
        :spoke_page_origin
      end

    # Split the HTML file into two parts, on the line that contains HUB_META_TAGS, so we can add meta tags
    case "#{module_config(config_key)}/#{page}"
         |> retry_get_until_success do
      :error ->
        # Nils are rejected after tasks are joined
        nil

      res ->
        chunks =
          res
          |> Map.get(:body)
          |> String.split("\n")
          |> Enum.split_while(&(!Regex.match?(~r/META_TAGS/, &1)))
          |> Tuple.to_list()

        {{source, page}, chunks}
    end
  end

  defp retry_get_until_success(url) do
    retry with: exp_backoff() |> randomize |> cap(5_000) |> expiry(10_000) do
      hackney_options =
        if module_config(:insecure_ssl) == true do
          [:insecure]
        else
          []
        end

      # For local dev, allow insecure SSL because of webpack server
      case HTTPoison.get(url, [], hackney: hackney_options) do
        {:ok, %HTTPoison.Response{status_code: 200} = resp} -> resp
        _ -> :error
      end
    after
      result -> result
    else
      error -> error
    end
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
