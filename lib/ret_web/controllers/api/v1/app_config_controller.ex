defmodule RetWeb.Api.V1.AppConfigController do
  use RetWeb, :controller
  alias Ret.{Repo, AppConfig}

  def create(conn, %{"app_config" => app_config_params}) do
    {result, app_config} =
      %AppConfig{}
      |> AppConfig.changeset(app_config_params)
      |> Repo.insert()

    case result do
      :ok -> render(conn, "create.json", app_config: app_config)
      :error -> conn |> send_resp(422, "invalid app config")
    end
  end
end
