defmodule Ret.HttpUtils do
  use Retry

  @internal_ipv4_cidr_list [
    InetCidr.parse("0.0.0.0/8"),
    InetCidr.parse("10.0.0.0/8"),
    InetCidr.parse("127.0.0.0/8"),
    InetCidr.parse("169.254.0.0/16"),
    InetCidr.parse("172.16.0.0/12"),
    InetCidr.parse("192.168.0.0/16")
  ]

  def retry_head_until_success(url, options \\ []),
    do: retry_until_success(:head, url, "", options)

  def retry_get_until_success(url, options \\ []),
    do: retry_until_success(:get, url, "", options)

  def retry_post_until_success(url, body, options \\ []),
    do: retry_until_success(:post, url, body, options)

  def retry_put_until_success(url, body, options \\ []),
    do: retry_until_success(:put, url, body, options)

  def retry_head_then_get_until_success(url, options \\ []) do
    case url |> retry_head_until_success(options) do
      :error ->
        url |> retry_get_until_success(options)

      res ->
        res
    end
  end

  defp retry_until_success(verb, url, body, options) do
    default_options = [
      headers: [],
      cap_ms: 5_000,
      expiry_ms: 10_000,
      append_browser_user_agent: false
    ]

    options = Keyword.merge(default_options, options)

    headers =
      if options[:append_browser_user_agent] do
        options[:headers] ++
          [{"User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:84.0) Gecko/20100101 Firefox/84.0"}]
      else
        options[:headers]
      end

    hackney_options =
      if module_config(:insecure_ssl) == true do
        [:insecure]
      else
        []
      end

    retry with: exponential_backoff() |> randomize |> cap(options[:cap_ms]) |> expiry(options[:expiry_ms]) do
      http_client = module_config(:http_client) || HTTPoison

      case http_client.request(verb, url, body, headers,
             follow_redirect: true,
             timeout: options[:cap_ms],
             recv_timeout: options[:cap_ms],
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
    case url |> retry_head_then_get_until_success(headers: [{"Range", "bytes=0-32768"}]) do
      :error -> {:error, "Could not get content-type"}
      %HTTPoison.Response{headers: headers} -> {:ok, headers |> content_type_from_headers}
    end
  end

  def get_forwarded_ip(headers) do
    origin_ips_csv = headers |> get_http_header("x-forwarded-for")

    if origin_ips_csv do
      origin_ips = origin_ips_csv |> String.split(",") |> Enum.map(&String.trim/1)

      # AWS' Application Load Balancer (ALB) will append the client's actual IP Address
      # at the end of the list of forwarded headers. Since we want to ignore any
      # spoofed IPs, we take the last IP in the list.
      # See https://docs.aws.amazon.com/elasticloadbalancing/latest/application/x-forwarded-headers.html#x-forwarded-for
      ip_str = origin_ips |> Enum.at(length(origin_ips) - 1)

      case :inet.parse_address(to_charlist(ip_str)) do
        {:ok, ip} -> ip
        _ -> nil
      end
    else
      nil
    end
  end

  def resolve_ip(host) do
    try do
      InetCidr.parse_address!(host)
    rescue
      _ ->
        case DNS.resolve(host) do
          {:ok, results} ->
            # TODO We should probably be able to handle ipv6 here too.
            results |> Enum.filter(&InetCidr.v4?/1) |> Enum.random()

          _ ->
            nil
        end
    end
  end

  def internal_ip?(ip_address) do
    case ip_address do
      nil ->
        # Default to true for safety.
        true

      {_, _, _, _} = ipv4_address ->
        Enum.any?(@internal_ipv4_cidr_list, fn cidr -> InetCidr.contains?(cidr, ipv4_address) end)

      _ ->
        # For safety, assume anything else is internal.
        true
    end
  end

  def replace_host(uri, ip_address) do
    Map.put(uri, :host, to_string(:inet.ntoa(ip_address)))
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end
end
