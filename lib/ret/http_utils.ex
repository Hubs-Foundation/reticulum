defmodule Ret.HttpUtils do
  use Retry

  def retry_get_until_success(url, headers \\ []) do
    retry with: exp_backoff() |> randomize |> cap(5_000) |> expiry(10_000) do
      case HTTPoison.get(url, headers, follow_redirect: true) do
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
end
