defmodule RetWeb.HubChannelTest do
  use RetWeb.ChannelCase
  import Ret.TestHelpers

  alias RetWeb.{Presence, SessionSocket}
  alias Ret.{AppConfig, Account, Repo, Hub}

  setup [:create_account, :create_owned_file, :create_scene, :create_hub, :create_account]

  setup do
    {:ok, socket} = connect(SessionSocket, %{})
    {:ok, socket: socket}
  end

  test "joining hub works", %{socket: socket, hub: hub} do
    {:ok, %{session_id: _session_id}, _socket} = subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params())
  end

  test "joining hub does not work if sign in required", %{socket: socket, scene: scene} do
    AppConfig.set_config_value("features|require_account_for_join", true)
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()
    {:error, _reason} = subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params())
    AppConfig.set_config_value("features|require_account_for_join", false)
  end

  test "joining hub does not work if account is disabled", %{socket: socket, hub: hub} do
    disabled_account = create_account("disabled_account")
    disabled_account |> Ecto.Changeset.change(state: :disabled) |> Ret.Repo.update!()

    {:error, %{reason: "join_denied"}} =
      subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(disabled_account))
  end

  test "joining hub registers in presence", %{socket: socket, hub: hub} do
    {:ok, %{session_id: session_id}, socket} = subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params())
    :timer.sleep(100)
    presence = socket |> Presence.list()
    assert presence[session_id]
  end

  test "joining hub with an account with an identity registers identity in presence", %{
    socket: socket,
    hub: hub,
    account: account
  } do
    account |> Account.set_identity!("Test User")

    {:ok, %{session_id: session_id}, socket} =
      subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

    :timer.sleep(100)
    presence = socket |> Presence.list()
    meta = presence[session_id][:metas] |> Enum.at(0)
    assert meta[:profile]["identityName"] === "Test User"
  end

  defp join_params, do: %{"profile" => %{}, "context" => %{}}

  defp join_params_for_account(account) do
    {:ok, token, _params} = account |> Ret.Guardian.encode_and_sign()
    %{"profile" => %{}, "context" => %{}, "auth_token" => token}
  end
end
