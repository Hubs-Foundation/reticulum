defmodule RetWeb.EntityTest do
  use RetWeb.ChannelCase
  import Ret.TestHelpers
  import RetWeb.EntityTestUtils, only: [read_json: 1]

  alias RetWeb.SessionSocket
  alias Ret.{Repo, HubRoleMembership}

  @payload_save_entity_state read_json("save_entity_state_payload.json")
  @payload_save_entity_state_2 read_json("save_entity_state_payload_2.json")
  @payload_update_entity_state read_json("update_entity_state_payload.json")
  @payload_delete_entity_state read_json("delete_entity_state_payload.json")
  @default_join_params %{"profile" => %{}, "context" => %{}}

  setup [:create_account, :create_owned_file, :create_scene, :create_hub, :create_account]

  setup do
    {:ok, socket} = connect(SessionSocket, %{})
    {:ok, socket: socket}
  end

  describe "entity states" do
    test "list_entity_states", %{socket: socket, hub: hub} do
      {:ok, _, socket} = subscribe_and_join(socket, "hub:#{hub.hub_sid}", @default_join_params)

      assert_reply push(socket, "list_entities", %{}), :ok, %{data: []}
    end

    test "save_entity_state creates an entity state", %{
      socket: socket,
      hub: hub,
      account: account
    } do
      %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()

      {:ok, _, socket} =
        subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

      assert_reply push(socket, "save_entity_state", @payload_save_entity_state), :ok
      assert_reply push(socket, "list_entities", %{}), :ok, %{data: [entity_state]}
      assert entity_state.create_message["networkId"] === @payload_save_entity_state["nid"]
      assert entity_state.create_message === @payload_save_entity_state["create_message"]

      Enum.zip(entity_state.update_messages, @payload_save_entity_state["updates"])
      |> Enum.each(fn {update_message, update_from_payload} ->
        assert update_message === update_from_payload["update_message"]
      end)
    end

    test "save_entity_state is denied if not logged in", %{
      socket: socket,
      hub: hub
    } do
      {:ok, _, socket} = subscribe_and_join(socket, "hub:#{hub.hub_sid}", @default_join_params)

      assert_reply push(socket, "save_entity_state", @payload_save_entity_state), :error, %{
        reason: :not_logged_in
      }
    end

    test "save_entity_state is denied if account lacks pin permissions", %{
      socket: socket,
      hub: hub,
      account: account
    } do
      {:ok, _, socket} =
        subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

      assert_reply push(socket, "save_entity_state", @payload_save_entity_state), :error, %{
        reason: :unauthorized
      }
    end
  end

  test "update_entity_state overwrites previous entity state", %{
    socket: socket,
    hub: hub,
    account: account
  } do
    %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()

    {:ok, _, socket} =
      subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

    push(socket, "save_entity_state", @payload_save_entity_state)
    assert_reply push(socket, "list_entities", %{}), :ok, %{data: [entity_state]}
    # The page starts at 2
    2 = Enum.at(entity_state.update_messages, 1)["data"]["networked-pdf"]["data"]["pageNumber"]

    push(socket, "update_entity_state", @payload_update_entity_state)
    assert_reply push(socket, "list_entities", %{}), :ok, %{data: [entity_state]}
    # The page was updated to 1
    assert Enum.at(entity_state.update_messages, 1)["data"]["networked-pdf"]["data"]["pageNumber"] ===
             1
  end

  test "delete_entity_state replies with error if entity does not exist", %{
    socket: socket,
    hub: hub,
    account: account
  } do
    %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()

    {:ok, _, socket} =
      subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

    non_existent_entity_payload = Map.put(@payload_delete_entity_state, "nid", "non_existent_nid")

    assert_reply push(socket, "delete_entity_state", non_existent_entity_payload), :error, %{
      reason: :entity_state_does_not_exist
    }
  end

  test "delete_entity_state replies with error if not authorized", %{
    socket: socket,
    hub: hub
  } do
    {:ok, _, socket} = subscribe_and_join(socket, "hub:#{hub.hub_sid}", @default_join_params)

    assert_reply push(socket, "delete_entity_state", @payload_delete_entity_state), :error, %{
      reason: :not_logged_in
    }
  end

  test "delete_entity_state deletes the entity with the matching nid", %{
    socket: socket,
    hub: hub,
    account: account
  } do
    %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()

    {:ok, _, socket} =
      subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

    push(socket, "save_entity_state", @payload_save_entity_state)
    push(socket, "save_entity_state", @payload_save_entity_state_2)
    assert_reply push(socket, "delete_entity_state", @payload_delete_entity_state), :ok
    assert_reply push(socket, "list_entities", %{}), :ok, %{data: [entity]}
    refute "ji5uv3q" === entity.create_message["networkedId"]
    assert entity.create_message["networkId"] === @payload_save_entity_state_2["nid"]
    assert entity.create_message === @payload_save_entity_state_2["create_message"]
  end

  defp join_params_for_account(account) do
    {:ok, token, _params} = account |> Ret.Guardian.encode_and_sign()
    join_params(%{"auth_token" => token})
  end

  defp join_params(%{} = params) do
    Map.merge(@default_join_params, params)
  end
end
