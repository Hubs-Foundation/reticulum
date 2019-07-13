defmodule Ret.Speelycaptor do
  import Ret.HttpUtils

  def convert(%Plug.Upload{path: path, content_type: content_type}, convert_to_content_type) do
    if content_type |> String.downcase() |> String.starts_with?(convert_to_content_type) do
      nil
    else
      convert(path, convert_to_content_type)
    end
  end

  def convert(path, "video/mp4") do
    with speelycaptor_endpoint when is_binary(speelycaptor_endpoint) <- module_config(:speelycaptor_endpoint) do
      case retry_get_until_success("#{speelycaptor_endpoint}/init") do
        :error ->
          nil

        resp ->
          resp_body = resp.body |> Poison.decode!()
          upload_url = resp_body |> Map.get("uploadUrl")
          key = resp_body |> Map.get("key")

          case retry_put_until_success(upload_url, {:file, path}, [], 30_000, 120_000) do
            :error ->
              nil

            _upload_resp ->
              case retry_get_until_success("#{speelycaptor_endpoint}/convert?key=#{key}&args=-f%20mp4") do
                :error ->
                  nil

                convert_resp ->
                  url = convert_resp.body |> Poison.decode!() |> Map.get("url")
                  {:ok, download_path} = Temp.path()
                  Download.from(url, path: download_path)
                  {:ok, download_path}
              end
          end
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
