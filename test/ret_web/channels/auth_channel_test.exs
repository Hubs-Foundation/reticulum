defmodule RetWeb.AuthChannelTest do
  use RetWeb.ChannelCase
  import Ecto.Query
  import Ret.TestHelpers

  alias RetWeb.{SessionSocket}
  alias Ret.{Account, AppConfig, Repo}

  @test_email "admin1@mozilla.com"
  @test_email2 "admin2@mozilla.com"

  setup [:create_account]

  setup do
    {:ok, socket} = connect(SessionSocket, %{})
    {:ok, %{session_id: _session_id}, socket} = subscribe_and_join(socket, "auth:testauth", %{})
    {:ok, socket: socket}
  end

  test "Login token is created for an email", %{socket: socket} do
    refute login_token_for_email_exists?(@test_email)
    refute Account.exists_for_email?(@test_email)

    push(socket, "auth_request", %{"email" => @test_email, "origin" => "test"})
    :timer.sleep(500)

    assert login_token_for_email_exists?(@test_email)
    refute Account.exists_for_email?(@test_email)
  end

  test "Login token is not created for an email if sign up is disabled", %{socket: socket} do
    refute login_token_for_email_exists?(@test_email2)
    AppConfig.set_config_value("features|disable_sign_up", true)

    push(socket, "auth_request", %{"email" => @test_email2, "origin" => "test"})
    :timer.sleep(500)

    token_exists = login_token_for_email_exists?(@test_email2)
    account_exists = Account.exists_for_email?(@test_email2)

    AppConfig.set_config_value("features|disable_sign_up", false)

    refute token_exists
    refute account_exists
  end

  test "Login token is not created for disabled account", %{socket: socket} do
    disabled_account = create_account("disabled_account")
    disabled_account |> Ecto.Changeset.change(state: :disabled) |> Ret.Repo.update!()

    push(socket, "auth_request", %{"email" => "disabled_account@mozilla.com", "origin" => "test"})
    :timer.sleep(500)

    refute login_token_for_email_exists?("disabled_account@mozilla.com")
  end

  defp login_token_for_email_exists?(email) do
    email_hash = Account.identifier_hash_for_email(email)
    Repo.exists?(from t in Ret.LoginToken, where: t.identifier_hash == ^email_hash)
  end
end
