defmodule Ret.PageOriginWarmer do
  use Cachex.Warmer
  use Retry
  import Ret.HttpUtils

  @pages %{
           hubs: ~w(
             index.html
             whats-new.html
             hub.html
             link.html
             scene.html
             avatar.html
             discord.html
             cloud.html
             signin.html
             verify.html
             hub.service.js
             schema.toml
           ),
           admin: ~w(admin.html),
           spoke: ~w(index.html)
         }
         |> Enum.map(fn {k, vs} -> vs |> Enum.map(&{k, &1}) end)
         |> List.flatten()

  def interval, do: :timer.seconds(15)

  def execute(_state) do
    with hubs_page_origin when is_binary(hubs_page_origin) <- module_config(:hubs_page_origin),
         admin_page_origin when is_binary(admin_page_origin) <- module_config(:admin_page_origin),
         spoke_page_origin when is_binary(spoke_page_origin) <- module_config(:spoke_page_origin) do
      # Don't bother with the full fetch if the aggregated etag hasn't changed
      case Cachex.get(:page_chunks, :last_aggregated_etag) do
        {:ok, last_aggregated_etag} ->
          latest_aggregated_etag = get_aggregated_etag()

          if last_aggregated_etag !== latest_aggregated_etag do
            cache_values =
              @pages
              |> Enum.map(fn {source, page} -> Task.async(fn -> page_to_cache_entry(source, page) end) end)
              |> Enum.map(&Task.await(&1, 15_000))
              |> Enum.reject(&is_nil/1)

            Cachex.put(:page_chunks, :last_aggregated_etag, latest_aggregated_etag)

            {:ok, cache_values}
          else
            :ignore
          end

        _ ->
          :ignore
      end
    else
      _ -> {:ok, []}
    end
  end

  def chunks_for_page(source, page) do
    case source |> page_to_cache_entry(page) do
      nil ->
        {:error}

      {_, result} ->
        {:ok, result}
    end
  end

  # Fetches and returns the latest last modified header for all of the pages
  defp get_aggregated_etag() do
    with hubs_page_origin when is_binary(hubs_page_origin) <- module_config(:hubs_page_origin),
         admin_page_origin when is_binary(admin_page_origin) <- module_config(:admin_page_origin),
         spoke_page_origin when is_binary(spoke_page_origin) <- module_config(:spoke_page_origin) do
      etags =
        @pages
        |> Enum.map(fn {source, page} -> Task.async(fn -> page_to_etag(source, page) end) end)
        |> Enum.map(&Task.await(&1, 15_000))
        |> Enum.reject(&is_nil/1)

      etags |> Enum.sort() |> Enum.join()
    else
      _ -> nil
    end
  end

  defp page_to_cache_entry(source, page) do
    # Split the HTML file into two parts, on the line that contains META_TAGS, so we can add meta tags
    case "#{module_config(config_key_for_source(source))}/#{page}"
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

  defp page_to_etag(source, page) do
    case "#{module_config(config_key_for_source(source))}/#{page}"
         |> retry_head_until_success do
      :error ->
        # Nils are rejected after tasks are joined
        nil

      res ->
        header = res.headers |> Enum.find(&(&1 |> elem(0) |> String.downcase() === "etag"))

        if header do
          header |> elem(1)
        else
          nil
        end
    end
  end

  defp config_key_for_source(:hubs), do: :hubs_page_origin
  defp config_key_for_source(:admin), do: :admin_page_origin
  defp config_key_for_source(:spoke), do: :spoke_page_origin

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
