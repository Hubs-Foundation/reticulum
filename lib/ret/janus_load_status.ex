defmodule Ret.JanusLoadStatus do
  use Cachex.Warmer
  use Retry

  import Ret.Stats

  def interval, do: :timer.seconds(15)

  def get_host_for_room do
    {:ok, host_to_ccu} = Cachex.get(:janus_load_status, :host_to_ccu)

    hosts_by_weight =
      host_to_ccu |> Enum.filter(&(elem(&1, 1) != nil)) |> Enum.map(fn {host, ccu} -> {host, ccu |> weight_for_ccu} end)

    hosts_by_weight |> weighted_sample |> Atom.to_string()
  end

  def execute(_state) do
    janus_hosts =
      with default_janus_host when is_binary(default_janus_host) <- module_config(:default_janus_host) do
        [default_janus_host] |> Enum.map(&:erlang.binary_to_atom(&1, :utf8))
      else
        _ -> module_config(:janus_service_name) |> Ret.Habitat.get_hosts_for_service()
      end

    entries =
      janus_hosts
      |> Enum.map(fn h -> Task.async(fn -> janus_host_to_ccu(h) end) end)
      |> Enum.map(&Task.await(&1, 30_000))

    {:ok, [{:host_to_ccu, entries}]}
  end

  # For given host return { host, ccu || nil } -- if nil then host admin interface is down/unreachable
  defp janus_host_to_ccu(janus_host) do
    with janus_secret when is_binary(janus_secret) <- module_config(:janus_secret) do
      janus_port = module_config(:janus_admin_port)

      janus_payload = %{
        janus: "list_sessions",
        transaction: :crypto.strong_rand_bytes(16) |> Base.url_encode64(),
        admin_secret: janus_secret
      }

      janus_resp = retry_api_post_until_success("http://#{janus_host}:#{janus_port}/admin", janus_payload)

      case janus_resp do
        %HTTPoison.Response{status_code: 200, body: body} ->
          {janus_host, body |> Poison.decode!() |> Kernel.get_in(["sessions"]) |> Enum.count()}

        _ ->
          {janus_host, nil}
      end
    else
      # No admin secret, don't perform load balancing
      _ -> {janus_host, 0}
    end
  end

  defp retry_api_post_until_success(url, payload) do
    retry with: exp_backoff() |> randomize |> cap(3_000) |> expiry(5_000) do
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

  # Gets the load balancing weight for the given CCU, which is the first entry in
  # the balancer_weights config that the CCU exceeds.
  def weight_for_ccu(ccu) do
    module_config(:balancer_weights) |> Enum.find(&(ccu >= elem(&1, 0))) |> elem(1) || 1
  end
end
