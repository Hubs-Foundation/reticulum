defmodule Ret.PeerageProvider do
  def poll do
    get_service_name()
    |> get_hosts_for_service
  end

  defp get_service_name do
    fetch_json("http://localhost:9631/services")
    |> Enum.map(&(&1["service_group"]))
    |> Enum.filter(&(String.starts_with?(&1, "reticulum")))
    |> List.first
  end

  defp get_hosts_for_service(nil) do
    []
  end

  defp get_hosts_for_service(service_name) do
    fetch_json("http://localhost:9631/census")
    |> get_in(["census_groups", service_name, "population"])
    |> Map.values
    |> Enum.map(&("ret@#{&1["sys"]["ip"]}"))
  end

  defp fetch_json(url) do
    %{ status_code: 200, body: body } = HTTPoison.get!(url)
    body |> Poison.decode!
  end
end
