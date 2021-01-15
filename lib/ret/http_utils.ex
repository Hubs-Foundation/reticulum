defmodule Ret.HttpUtils do
  use Retry

  def retry_head_until_success(url, headers \\ [], cap_ms \\ 5_000, expiry_ms \\ 10_000),
    do: retry_until_success(:head, url, "", headers, cap_ms, expiry_ms)

  def retry_get_until_success(url, headers \\ [], cap_ms \\ 5_000, expiry_ms \\ 10_000),
    do: retry_until_success(:get, url, "", headers, cap_ms, expiry_ms)

  def retry_post_until_success(url, body, headers \\ [], cap_ms \\ 5_000, expiry_ms \\ 10_000),
    do: retry_until_success(:post, url, body, headers, cap_ms, expiry_ms)

  def retry_put_until_success(url, body, headers \\ [], cap_ms \\ 5_000, expiry_ms \\ 10_000),
    do: retry_until_success(:put, url, body, headers, cap_ms, expiry_ms)

  def retry_head_then_get_until_success(url, headers \\ [], cap_ms \\ 5_000, expiry_ms \\ 10_000) do
    case url |> retry_head_until_success(headers, cap_ms, expiry_ms) do
      :error ->
        url |> retry_get_until_success(headers, cap_ms, expiry_ms)

      res ->
        res
    end
  end

  def retry_until_success(verb, url, body \\ "", headers \\ [], cap_ms \\ 5_000, expiry_ms \\ 10_000) do
    headers = headers ++ [{"User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:84.0) Gecko/20100101 Firefox/84.0"}]

    hackney_options =
      if module_config(:insecure_ssl) == true do
        [:insecure]
      else
        []
      end

    retry with: exponential_backoff() |> randomize |> cap(cap_ms) |> expiry(expiry_ms) do
      case HTTPoison.request(verb, url, body, headers,
             follow_redirect: true,
             timeout: cap_ms,
             recv_timeout: cap_ms,
             hackney: hackney_options
           ) do
        {:ok, %HTTPoison.Response{status_code: status_code} = resp}
        when status_code >= 200 and status_code < 300 ->
          resp

        {:ok, %HTTPoison.Response{status_code: status_code}}
        when status_code >= 400 and status_code < 500 ->
          :unauthorized

        _ ->
          :error
      end
    after
      result ->
        case result do
          :unauthorized -> :error
          _ -> result
        end
    else
      error -> error
    end
  end

  def get_http_header(headers, header) do
    header = headers |> Enum.find(fn h -> h |> elem(0) |> String.downcase() === header end)

    if header do
      header |> elem(1)
    else
      nil
    end
  end

  def content_type_from_headers(headers) do
    headers |> get_http_header("content-type")
  end

  def fetch_content_type(url) do
    case url |> retry_head_then_get_until_success([{"Range", "bytes=0-32768"}]) do
      :error -> {:error, "Could not get content-type"}
      %HTTPoison.Response{headers: headers} -> {:ok, headers |> content_type_from_headers}
    end
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
