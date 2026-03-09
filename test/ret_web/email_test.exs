defmodule RetWeb.EmailTest do
  use RetWeb.ConnCase
  alias RetWeb.Email
  alias Ret.AppConfig

  setup do
    Application.put_env(:ret, RetWeb.Email, from: "noreply")
    :ok
  end

  @to_address "test@example.com"
  @signin_args %{"token" => "test-token", "auth_foo" => "42"}

  describe "auth_email/2" do
    # When testing, the reticulum endpoint listens on localhost port 4001.
    # When no app-name is set in translations, the domain name is used.
    # So, when testing, the default app-name is "localhost"
    test "returns an email with default subject and body" do
      email = Email.auth_email(@to_address, @signin_args)

      assert email.from == {"localhost", "noreply"}
      assert email.to == @to_address
      assert email.subject == "Your localhost Sign-In Link"
      assert email.text_body =~ "To sign-in to localhost, please visit the link below."
      assert email.text_body =~ "http://localhost:4001/?auth_foo=42&token=test-token"
    end

    test "returns an email with custom app name" do
      AppConfig.set_config_value("translations|en|app-name", "My Hubs Instance")

      email = Email.auth_email(@to_address, @signin_args)

      assert email.subject == "Your My Hubs Instance Sign-In Link"
      assert email.text_body =~ "To sign-in to My Hubs Instance, please visit the link below."

      AppConfig.set_config_value("translations|en|app-name", nil)
    end

    test "returns an email with custom subject" do
      AppConfig.set_config_value("auth|login_subject", "Custom Login Subject")

      email = Email.auth_email(@to_address, @signin_args)

      assert email.subject == "Custom Login Subject"

      AppConfig.set_config_value("auth|login_subject", nil)
    end

    test "returns an email with custom body and {{ link }} replacement" do
      AppConfig.set_config_value("auth|login_body", "Surf to: {{ link }} to log in.")

      email = Email.auth_email(@to_address, @signin_args)

      assert email.text_body =~
               "Surf to: http://localhost:4001/?auth_foo=42&token=test-token to log in."

      AppConfig.set_config_value("auth|login_body", nil)
    end

    test "returns an email with custom body appending link if {{ link }} is missing" do
      AppConfig.set_config_value("auth|login_body", "Custom body without placeholder.")

      email = Email.auth_email(@to_address, @signin_args)

      assert email.text_body =~
               "Custom body without placeholder.\n\nhttp://localhost:4001/?auth_foo=42&token=test-token"

      AppConfig.set_config_value("auth|login_body", nil)
    end

    test "includes Return-Path header if admin_email is set" do
      # admin_email is set to "admin@hubsfoundation.org" in config/test.exs
      email = Email.auth_email(@to_address, @signin_args)
      assert email.headers["Return-Path"] == "admin@hubsfoundation.org"
    end

    test "omits Return-Path header if admin_email is set and TURKEY_MODE enabled" do
      # admin_email is set to "admin@hubsfoundation.org" in config/test.exs
      System.put_env("TURKEY_MODE", "1")

      on_exit(fn ->
        System.delete_env("TURKEY_MODE")
      end)

      email = Email.auth_email(@to_address, @signin_args)
      refute Map.has_key?(email.headers, "Return-Path")
    end

    test "omits Return-Path header if admin_email is not set" do
      # admin_email is set to "admin@hubsfoundation.org" in config/test.exs
      admin_email = Application.get_env(:ret, Ret.Account)[:admin_email]
      Application.put_env(:ret, Ret.Account, admin_email: nil)

      on_exit(fn ->
        Application.put_env(:ret, Ret.Account, admin_email: admin_email)
      end)

      email = Email.auth_email(@to_address, @signin_args)
      refute Map.has_key?(email.headers, "Return-Path")
    end
  end
end
