defmodule Ret.PageOriginWarmer do
  use Cachex.Warmer
  use Retry

  @pages ~w(index hub link scene spoke avatar-selector)

  def interval, do: :timer.seconds(15)

  def execute(_state) do
    with page_origin when is_binary(page_origin) <- module_config(:page_origin) do
      cache_values =
        @pages
        |> Enum.map(&Task.async(fn -> page_to_cache_entry(&1) end))
        |> Enum.map(&Task.await(&1, 15000))
        |> Enum.reject(&is_nil/1)

      {:ok, cache_values}
    else
      _ -> {:ok, []}
    end
  end

  defp page_to_cache_entry(page) do
    # Split the HTML file into two parts, on the line that contains HUB_META_TAGS, so we can add meta tags
    case "#{module_config(:page_origin)}/#{page}.html"
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

        {page, chunks}
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
