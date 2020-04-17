defmodule Ret.Habitat do
  def get_service_members(nil) do
    []
  end

  # Returns { host, ip } tuples for the given services
  def get_service_members(service_name) do
    habitat_config = Application.get_env(:ret, Ret.Habitat)
    habitat_ip = habitat_config[:ip]
    habitat_port = habitat_config[:http_port]
    census_url = "http://#{habitat_ip}:#{habitat_port}/census"

    %{status_code: 200, body: census_body} = HTTPoison.get!(census_url)
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
    |> Enum.map(&{&1["sys"]["hostname"], &1["sys"]["ip"]})
  end
end
