defmodule Ret.Speelycaptor do
  import Ret.HttpUtils

  def convert(%Plug.Upload{path: path, content_type: "video/" <> _tail}, "video/mp4") do
    with speelycaptor_endpoint when is_binary(speelycaptor_endpoint) <- module_config(:speelycaptor_endpoint) do
      case retry_get_until_success("#{speelycaptor_endpoint}/init") do
        %HTTPoison.Response{body: body} ->
          resp_body = body |> Poison.decode!()
          upload_url = resp_body |> Map.get("uploadUrl")
          key = resp_body |> Map.get("key")
          upload_and_convert_mp4(speelycaptor_endpoint, upload_url, path, key)

        :error ->
          nil
      end
    else
      _ -> nil
    end
  end

  def convert(_path, _content_type), do: nil

  defp upload_and_convert_mp4(endpoint, upload_url, path, key) do
    case retry_put_until_success(upload_url, {:file, path}, cap_ms: 30_000, expiry_ms: 120_000) do
      %HTTPoison.Response{} ->
        query = %{
          key: key,
          args: "-f mp4 -vcodec libx264 -preset fast -profile:v main -r 24 -acodec aac"
        }

        case retry_get_until_success(
               "#{endpoint}/convert?#{URI.encode_query(query)}",
               cap_ms: 30_000,
               expiry_ms: 120_000
             ) do
          %HTTPoison.Response{body: body} ->
            url = body |> Poison.decode!() |> Map.get("url")
            {:ok, download_path} = Temp.path()
            Download.from(url, path: download_path)
            {:ok, download_path}

          :error ->
            nil
        end

      :error ->
        nil
    end
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
