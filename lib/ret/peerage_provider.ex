defmodule Ret.PeerageProvider do
  def poll do
    get_service_name()
    |> get_hosts_for_service
  end

  defp get_service_name do
    habitat_config = Application.get_env(:ret, Ret.PeerageProvider)
    habitat_ip = habitat_config[:ip]
    habitat_port = habitat_config[:http_port]

    fetch_json("http://#{habitat_ip}:#{habitat_port}/services")
    |> Enum.map(&(&1["service_group"]))
    |> Enum.filter(&(String.starts_with?(&1, "reticulum")))
    |> List.first
  end

  defp get_hosts_for_service(nil) do
    []
  end

  defp get_hosts_for_service(service_name) do
    habitat_config = Application.get_env(:ret, Ret.PeerageProvider)
    habitat_ip = habitat_config[:ip]
    habitat_port = habitat_config[:http_port]

    fetch_json("http://#{habitat_ip}:#{habitat_port}/census")
    |> get_in(["census_groups", service_name, "population"])
    |> Map.values
    |> Enum.map(&("ret@#{hostname_to_local(&1["sys"]["hostname"])}"))
    |> Enum.map(&(:erlang.binary_to_atom(&1, :utf8)))
  end

  defp hostname_to_local(hostname) do
    [name | tail] = String.split(hostname, ".")
    Enum.join(["#{name}-local" | tail], ".")
  end

  defp fetch_json(url) do
    %{ status_code: 200, body: body } = HTTPoison.get!(url)
    body |> Poison.decode!
  end
end
