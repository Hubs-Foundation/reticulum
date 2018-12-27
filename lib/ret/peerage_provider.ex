defmodule Ret.PeerageProvider do
  alias Ret.Habitat

  def poll do
    Habitat.get_service_name()
    |> Habitat.get_hosts_for_service(&hostname_to_erlang_node/1)
  end

  defp hostname_to_erlang_node(hostname) do
    [name | tail] = String.split(hostname, ".")
    Enum.join(["ret@#{name}-local" | tail], ".")
  end
end
