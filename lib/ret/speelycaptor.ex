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
          upload_url = resp.body |> Poison.decode!() |> Map.get("uploadUrl")

          case retry_post_until_success(upload_url, {:file, path}, [], 30_000, 120_000) do
            :error ->
              nil

            upload_resp ->
              IO.inspect(upload_resp)
          end

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
