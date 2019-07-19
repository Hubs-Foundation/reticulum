defmodule Ret.HttpUtils do
  use Retry

  def retry_head_until_success(url, headers \\ [], cap_ms \\ 5_000, expiry_ms \\ 10_000),
    do: retry_until_success(:head, url, "", headers, cap_ms, expiry_ms)

  def retry_get_until_success(url, headers \\ [], cap_ms \\ 5_000, expiry_ms \\ 10_000),
    do: retry_until_success(:get, url, "", headers, cap_ms, expiry_ms)

  def retry_post_until_success(url, body, headers \\ [], cap_ms \\ 5_000, expiry_ms \\ 10_000),
    do: retry_until_success(:post, url, body, headers, cap_ms, expiry_ms)

  def retry_head_then_get_until_success(url, headers \\ [], cap_ms \\ 5_000, expiry_ms \\ 10_000) do
    case url |> retry_head_until_success(headers, cap_ms, expiry_ms) do
      :error ->
        url |> retry_get_until_success(headers, cap_ms, expiry_ms)

      res ->
        res
    end
  end

  def retry_until_success(verb, url, body \\ "", headers \\ [], cap_ms \\ 5_000, expiry_ms \\ 10_000) do
    hackney_options =
      if module_config(:insecure_ssl) == true do
        [:insecure]
      else
        []
      end

    retry with: exp_backoff() |> randomize |> cap(cap_ms) |> expiry(expiry_ms) do
      case HTTPoison.request(verb, url, body, headers, follow_redirect: true, hackney: hackney_options) do
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

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
