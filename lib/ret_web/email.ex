defmodule RetWeb.Email do
  use Bamboo.Phoenix, view: RetWeb.EmailView
  alias Ret.{AppConfig}

  def auth_email(to_address, signin_args) do
    app_name = AppConfig.get_cached_config_value("translations|en|app-name")
    app_full_name = AppConfig.get_cached_config_value("translations|en|app-full-name") || app_name

    new_email()
    |> to(to_address)
    |> from({app_full_name, from_address()})
    |> subject("Your #{app_name} Sign-In Link")
    |> text_body(
      "To sign-in to #{app_name}, please visit the link below. If you did not make this request, please ignore this e-mail.\n\n#{
        RetWeb.Endpoint.url()
      }/?#{URI.encode_query(signin_args)}"
    )
  end

  defp from_address do
    Application.get_env(:ret, __MODULE__)[:from]
  end
end
