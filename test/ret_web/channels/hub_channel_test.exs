defmodule RetWeb.HubChannelTest do
  use RetWeb.ChannelCase
  import Ret.TestHelpers

  alias RetWeb.{Presence, SessionSocket}
  alias Ret.{AppConfig, Account, Repo, Hub, HubInvite}

  @default_join_params %{"profile" => %{}, "context" => %{}}

  setup [:create_account, :create_owned_file, :create_scene, :create_hub, :create_account]

  setup do
    {:ok, socket} = connect(SessionSocket, %{})
    {:ok, socket: socket}
  end

  describe "authorization" do
    test "joining hub works", %{socket: socket, hub: hub} do
      {:ok, %{session_id: _session_id}, _socket} =
        subscribe_and_join(socket, "hub:#{hub.hub_sid}", @default_join_params)
    end

    test "joining hub does not work if sign in required", %{socket: socket, scene: scene} do
      AppConfig.set_config_value("features|require_account_for_join", true)
      {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()
      {:error, _reason} = subscribe_and_join(socket, "hub:#{hub.hub_sid}", @default_join_params)
      AppConfig.set_config_value("features|require_account_for_join", false)
    end

    test "joining hub does not work if account is disabled", %{socket: socket, hub: hub} do
      disabled_account = create_account("disabled_account")
      disabled_account |> Ecto.Changeset.change(state: :disabled) |> Ret.Repo.update!()

      {:error, %{reason: "join_denied"}} =
        subscribe_and_join(
          socket,
          "hub:#{hub.hub_sid}",
          join_params_for_account(disabled_account)
        )
    end
  end

  describe "presence" do
    test "joining hub registers in presence", %{socket: socket, hub: hub} do
      {:ok, %{session_id: session_id}, socket} =
        subscribe_and_join(socket, "hub:#{hub.hub_sid}", @default_join_params)

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
  end

  describe "hub invites" do
    test "join is denied when joining without an invite", %{socket: socket} do
      %{hub: hub} = create_invite_only_hub()

      {:error, %{reason: "join_denied"}} = join_hub(socket, hub, @default_join_params)
    end

    test "join is denied when joining with an invalid invite", %{socket: socket} do
      %{hub: hub} = create_invite_only_hub()

      {:error, %{reason: "join_denied"}} =
        join_hub(socket, hub, join_params_for_hub_invite_id("invalid_invite_id"))
    end

    test "join is denied when joining with a revoked invite", %{socket: socket} do
      %{hub: hub, hub_invite: hub_invite} = create_invite_only_hub()

      Ret.HubInvite.revoke_invite(hub, hub_invite.hub_invite_sid)

      {:error, %{reason: "join_denied"}} =
        join_hub(socket, hub, join_params_for_hub_invite(hub_invite))
    end

    test "join is denied when joining with a mismatched invite", %{socket: socket} do
      %{hub: hub_one} = create_invite_only_hub()
      %{hub: _hub_two, hub_invite: hub_two_invite} = create_invite_only_hub()

      # Attempt to join hub_one, using invite associated with hub_two
      {:error, %{reason: "join_denied"}} =
        join_hub(
          socket,
          hub_one,
          join_params_for_hub_invite(hub_two_invite)
        )
    end

    test "revoke cannot be performed by an anonymous user", %{socket: socket} do
      %{hub: hub, hub_invite: hub_invite} = create_invite_only_hub()

      # Join hub as anonymous user
      {:ok, _context, socket} = join_hub(socket, hub, join_params_for_hub_invite(hub_invite))

      # Attempt to revoke invite
      push(socket, "revoke_invite", %{hub_invite_id: hub_invite.hub_invite_sid})
      |> assert_reply(:ok, %{})

      # Join is still denied with invalid invite
      {:error, %{reason: "join_denied"}} =
        join_hub(socket, hub, join_params_for_hub_invite_id("invalid_invite_id"))

      # Join is still allowed with original invite
      {:ok, _context, _socket} = join_hub(socket, hub, join_params_for_hub_invite(hub_invite))
    end

    test "revoke is keyed to hub", %{socket: socket} do
      %{hub: hub_one} = create_invite_only_hub()
      %{hub: hub_two, hub_invite: hub_two_invite} = create_invite_only_hub()

      account_one = create_account("account_one")
      assign_creator(hub_one, account_one)

      # Join hub_one
      {:ok, _context, socket} = join_hub(socket, hub_one, join_params_for_account(account_one))

      # Attempt to revoke invite associated with hub_two, using channel associated with hub_one
      %{payload: response_payload} =
        push(socket, "revoke_invite", %{hub_invite_id: hub_two_invite.hub_invite_sid})
        |> assert_reply(:ok, %{})

      # Response payload should be empty when a revoke is ignored
      assert response_payload |> Map.keys() |> length === 0

      # Joining hub_two is still denied with invalid invite
      {:error, %{reason: "join_denied"}} =
        join_hub(socket, hub_two, join_params_for_hub_invite_id("invalid_invite_id"))

      # Joining hub_two still allowed with original invite
      {:ok, _context, _socket} =
        join_hub(socket, hub_two, join_params_for_hub_invite(hub_two_invite))
    end

    test "revoke can be performed by hub creator", %{socket: socket} do
      %{hub: hub, hub_invite: hub_invite} = create_invite_only_hub()

      account = create_account("test_account")
      assign_creator(hub, account)

      {:ok, _context, socket} = join_hub(socket, hub, join_params_for_account(account))

      push(socket, "revoke_invite", %{hub_invite_id: hub_invite.hub_invite_sid})
      |> assert_reply(:ok, %{hub_invite_id: new_hub_invite_id})

      assert new_hub_invite_id !== hub_invite.hub_invite_sid
    end

    test "join is allowed on an invite-only hub with a correct invite id", %{socket: socket} do
      %{hub: hub, hub_invite: hub_invite} = create_invite_only_hub()

      {:ok, _context, _socket} = join_hub(socket, hub, join_params_for_hub_invite(hub_invite))
    end
  end

  defp join_params_for_hub_invite(%HubInvite{} = hub_invite) do
    join_params_for_hub_invite_id(hub_invite.hub_invite_sid)
  end

  defp join_params_for_hub_invite_id(hub_invite_id) do
    join_params(%{"hub_invite_id" => hub_invite_id})
  end

  defp join_params_for_account(account) do
    {:ok, token, _params} = account |> Ret.Guardian.encode_and_sign()
    join_params(%{"auth_token" => token})
  end

  defp join_params(%{} = params) do
    Map.merge(@default_join_params, params)
  end

  defp join_hub(socket, %Hub{} = hub, params) do
    subscribe_and_join(socket, "hub:#{hub.hub_sid}", params)
  end

  defp create_invite_only_hub() do
    {:ok, hub: hub} = create_hub(%{scene: nil})

    hub
    |> Ret.Hub.changeset_for_entry_mode(:invite)
    |> Ret.Repo.update!()

    hub_invite = Ret.HubInvite.find_or_create_invite_for_hub(hub)

    %{hub: hub, hub_invite: hub_invite}
  end
end
