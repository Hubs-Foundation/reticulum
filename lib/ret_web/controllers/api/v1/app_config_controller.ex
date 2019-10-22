defmodule RetWeb.Api.V1.AppConfigController do
  use RetWeb, :controller
  alias Ret.{Repo, AppConfig}

  def create(conn, params) do
    {:ok, body, conn} = conn |> Plug.Conn.read_body()

    # We expect the request body to be a json object where the leaf nodes are the config values.
    collapsed_config = body |> Poison.decode!() |> collapse("")

    collapsed_config
    |> Enum.each(fn {key, val} ->
      %AppConfig{}
      |> AppConfig.changeset(%{"key" => key, "value" => val})
      |> Repo.insert!()
    end)

    conn |> send_resp(200, "")
  end

  defp collapse(config, parent_key) do
    case config do
      %{} -> config |> Enum.flat_map(fn {key, val} -> collapse(val, parent_key <> "_" <> key) end)
      _ -> [{parent_key |> String.trim("_"), config}]
    end
  end

  def index(conn, _params) do
    conn |> send_resp(200, AppConfig.get_config() |> Poison.encode!())
  end
end
