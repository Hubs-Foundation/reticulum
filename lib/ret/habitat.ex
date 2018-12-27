defmodule Ret.Habitat do
  def get_hosts_for_service(nil) do
    []
  end

  def get_hosts_for_service(service_name, hostname_xform \\ fn x -> x end) do
    habitat_config = Application.get_env(:ret, Ret.Habitat)
    habitat_ip = habitat_config[:ip]
    habitat_port = habitat_config[:http_port]
    census_url = "http://#{habitat_ip}:#{habitat_port}/census"

    %{status_code: 200, body: census_body} = HTTPoison.get!(url)
    census_json = census_body |> Poison.decode!()

    full_service_name =
      census_json
      |> get_in(["census_groups"])
      |> Map.keys()
      |> Enum.filter(&String.starts_with?(&1, "#{service_name}."))
      |> List.first()

    census_json
    |> get_in(["census_groups", full_service_name, "population"])
    |> Map.values()
    |> Enum.filter(&(&1["alive"] == true))
    |> Enum.map(&hostname_xform.(&1["sys"]["hostname"]))
    |> Enum.map(&:erlang.binary_to_atom(&1, :utf8))
  end
end
