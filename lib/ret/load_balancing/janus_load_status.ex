defmodule Ret.JanusLoadStatus do
  use Cachex.Warmer
  use Retry

  def interval, do: :timer.seconds(15)

  def execute(_state) do
    with default_janus_host when is_binary(default_janus_host) and default_janus_host != "" <-
           module_config(:default_janus_host) do
      {:ok, [{:host_to_ccu, [{default_janus_host, 0}]}]}
    else
      _ ->
        entries =
          module_config(:janus_service_name)
          |> Ret.Habitat.get_service_members()
          |> Enum.map(fn {host, ip} -> Task.async(fn -> {host, janus_ip_to_ccu(ip)} end) end)
          |> Enum.map(&Task.await(&1, 10_000))

        {:ok, [{:host_to_ccu, entries}]}
    end
  end

  # For given host return { host, ccu || nil } -- if nil then host admin interface is down/unreachable
  defp janus_ip_to_ccu(janus_ip) do
    with janus_secret when is_binary(janus_secret) <- module_config(:janus_admin_secret) do
      janus_port = module_config(:janus_admin_port)

      janus_payload = %{
        janus: "list_sessions",
        transaction: :crypto.strong_rand_bytes(16) |> Base.url_encode64(),
        admin_secret: janus_secret
      }

      janus_resp = retry_api_post_until_success("http://#{janus_ip}:#{janus_port}/admin", janus_payload)

      case janus_resp do
        %HTTPoison.Response{status_code: 200, body: body} ->
          body |> Poison.decode!() |> Kernel.get_in(["sessions"]) |> Enum.count()

        _ ->
          nil
      end
    else
      # No admin secret, don't perform load balancing
      _ -> 0
    end
  end

  defp retry_api_post_until_success(url, payload) do
    retry with: exponential_backoff() |> randomize |> cap(3_000) |> expiry(5_000) do
      hackney_options =
        if module_config(:insecure_ssl) == true do
          [:insecure]
        else
          []
        end

      # For local dev, allow insecure SSL because of webpack server
      case HTTPoison.post(url, payload |> Poison.encode!(), [{"Content-Type", "application/json"}],
             hackney: hackney_options
           ) do
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
