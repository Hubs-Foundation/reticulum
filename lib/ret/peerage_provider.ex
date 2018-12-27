defmodule Ret.PeerageProvider do
  alias Ret.Habitat

  def poll do
    Habitat.get_hosts_for_service("reticulum", &hostname_to_erlang_node/1)
    |> Enum.filter(&(&1 != Node.self()))
  end

  defp hostname_to_erlang_node(hostname) do
    [name | tail] = String.split(hostname, ".")
    Enum.join(["ret@#{name}-local" | tail], ".")
  end
end
