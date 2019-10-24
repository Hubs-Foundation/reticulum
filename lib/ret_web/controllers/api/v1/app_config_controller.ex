defmodule RetWeb.Api.V1.AppConfigController do
  use RetWeb, :controller
  alias Ret.{Repo, AppConfig}

  def create(conn, params) do
    {:ok, body, conn} = conn |> Plug.Conn.read_body()

    # We expect the request body to be a json object where the leaf nodes are the config values.
    collapsed_config = body |> Poison.decode!() |> AppConfig.collapse()

    collapsed_config
    |> Enum.each(fn {key, val} ->
      (AppConfig |> Repo.get_by(key: key) || %AppConfig{})
      |> AppConfig.changeset(%{"key" => key, "value" => val})
      |> Repo.insert_or_update!()
    end)

    conn |> send_resp(200, "")
  end

  def index(conn, _params) do
    conn |> send_resp(200, AppConfig.get_config() |> Poison.encode!())
  end
end
