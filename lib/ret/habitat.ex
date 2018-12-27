defmodule Ret.Habitat do
  def get_hosts_for_service(nil) do
    []
  end

  def get_hosts_for_service(service_name, hostname_xform \\ fn x -> x end) do
    full_service_name = service_name |> get_full_service_name
    habitat_config = Application.get_env(:ret, Ret.Habitat)
    habitat_ip = habitat_config[:ip]
    habitat_port = habitat_config[:http_port]

    fetch_json("http://#{habitat_ip}:#{habitat_port}/census")
    |> get_in(["census_groups", full_service_name, "population"])
    |> Map.values()
    |> Enum.filter(&(&1["alive"] == true))
    |> Enum.map(&hostname_xform.(&1["sys"]["hostname"]))
    |> Enum.map(&:erlang.binary_to_atom(&1, :utf8))
  end

  defp get_full_service_name(service_name) do
    habitat_config = Application.get_env(:ret, Ret.Habitat)
    habitat_ip = habitat_config[:ip]
    habitat_port = habitat_config[:http_port]

    "http://#{habitat_ip}:#{habitat_port}/services"
    |> fetch_json
    |> Enum.map(& &1["service_group"])
    |> Enum.filter(&String.starts_with?(&1, service_name))
    |> List.first()
  end

  defp fetch_json(url) do
    %{status_code: 200, body: body} = HTTPoison.get!(url)
    body |> Poison.decode!()
  end
end
