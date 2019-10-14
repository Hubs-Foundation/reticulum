defmodule RetWeb.Api.V1.AppConfigView do
  use RetWeb, :view
  alias Ret.{AppConfig}

  def render("create.json", %{app_config: app_config}) do
    %{
      status: :ok,
      app_config_id: app_config.app_config_id
    }
  end
end
