defmodule Ret.RoomAssigner do
  use GenServer

  import Ret.Stats

  def init(state) do
    {:ok, state}
  end

  def is_alive?(nil), do: false

  def is_alive?(host) do
    {:ok, host_to_ccu} = Cachex.get(:janus_load_status, :host_to_ccu)
    host_to_ccu |> Keyword.keys() |> Enum.find(&(Atom.to_string(&1) == host)) != nil
  end

  def get_available_host(existing_host \\ nil) do
    GenServer.call({:global, __MODULE__}, {:get_available_host, existing_host})
  end

  def handle_call({:get_available_host, existing_host}, _pid, state) do
    host =
      if is_alive?(existing_host) do
        existing_host
      else
        pick_host()
      end

    {:reply, host, state}
  end

  defp pick_host do
    {:ok, host_to_ccu} = Cachex.get(:janus_load_status, :host_to_ccu)

    hosts_by_weight =
      host_to_ccu |> Enum.filter(&(elem(&1, 1) != nil)) |> Enum.map(fn {host, ccu} -> {host, ccu |> weight_for_ccu} end)

    picked_host = hosts_by_weight |> weighted_sample

    if picked_host
      picked_host |> Atom.to_string()
    else
      nil
    end
  end

  defp module_config(key) do
    Application.get_env(:ret, __MODULE__)[key]
  end

  # Gets the load balancing weight for the given CCU, which is the first entry in
  # the balancer_weights config that the CCU exceeds.
  defp weight_for_ccu(ccu) do
    module_config(:balancer_weights) |> Enum.find(&(ccu >= elem(&1, 0))) |> elem(1) || 1
  end
end
