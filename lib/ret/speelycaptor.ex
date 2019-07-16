defmodule Ret.Speelycaptor do
  import Ret.HttpUtils

  def convert(%Plug.Upload{path: path, content_type: "video/" <> _tail}, "video/mp4") do
    with speelycaptor_endpoint when is_binary(speelycaptor_endpoint) <- module_config(:speelycaptor_endpoint) do
      case retry_get_until_success("#{speelycaptor_endpoint}/init") do
        %HTTPoison.Response{body: body} ->
          resp_body = body |> Poison.decode!()
          upload_url = resp_body |> Map.get("uploadUrl")
          key = resp_body |> Map.get("key")

          query = %{
            key: key,
            args: "-f mp4 -r 24"
          }

          case retry_put_until_success(upload_url, {:file, path}, [], 30_000, 120_000) do
            %HTTPoison.Response{} ->
              case retry_get_until_success(
                     "#{speelycaptor_endpoint}/convert?#{URI.encode_query(query)}",
                     [],
                     30_000,
                     120_000
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

        :error ->
          nil
      end
    else
      _ -> nil
    end
  end

  def convert(_path, _content_type), do: nil

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
