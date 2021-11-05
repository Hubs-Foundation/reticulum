defmodule RetWeb.Email do
  use Bamboo.Phoenix, view: RetWeb.EmailView
  alias Ret.{AppConfig}

  def auth_email(to_address, signin_args) do
    app_name = AppConfig.get_cached_config_value("translations|en|app-name")
    app_full_name = AppConfig.get_cached_config_value("translations|en|app-full-name") || app_name
    admin_email = Application.get_env(:ret, Ret.Account)[:admin_email]
    custom_login_subject = AppConfig.get_cached_config_value("auth|login_subject")
    custom_login_body = AppConfig.get_cached_config_value("auth|login_body")

    email_subject =
      if string_is_nil_or_empty(custom_login_subject),
        do: "Your #{app_name} Sign-In Link",
        else: custom_login_subject

    email_body =
      if string_is_nil_or_empty(custom_login_body),
        do:
          "To sign-in to #{app_name}, please visit the link below. If you did not make this request, please ignore this e-mail.\n\n #{
            RetWeb.Endpoint.url()
          }/?#{URI.encode_query(signin_args)}",
        else: add_magic_link_to_custom_login_body(custom_login_body, signin_args)

    email =
      new_email()
      |> to(to_address)
      |> from({app_full_name, from_address()})
      |> subject(email_subject)
      |> text_body(email_body)

    # if admin_email do
    #   email |> put_header("Return-Path", admin_email)
    # else
    #   email
    # end

    email

  end

  defp string_is_nil_or_empty(check_string) do
    check_string == nil || String.length(String.trim(check_string)) == 0
  end

  defp add_magic_link_to_custom_login_body(custom_message, signin_args) do
    magic_link = "#{RetWeb.Endpoint.url()}/?#{URI.encode_query(signin_args)}"

    if Regex.match?(~r/{{ link }}/, custom_message) do
      Regex.replace(~r/{{ link }}/, custom_message, magic_link)
    else
      custom_message <> "\n\n" <> magic_link
    end
  end

  def enabled? do
    !!Application.get_env(:ret, Ret.Mailer)[:adapter]
  end

  defp from_address do
    Application.get_env(:ret, __MODULE__)[:from]
  end
end
