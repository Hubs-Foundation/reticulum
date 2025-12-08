defmodule RetWeb.EntityTest do
  use RetWeb.ChannelCase
  import Ret.TestHelpers
  import RetWeb.EntityTestUtils, only: [read_json: 1]

  alias RetWeb.SessionSocket
  alias Ret.{Repo, HubRoleMembership, Storage}

  @payload_save_entity_state read_json("save_entity_state_payload.json")
  @payload_save_entity_state_2 read_json("save_entity_state_payload_2.json")
  @payload_save_entity_state_promotable_no_token read_json(
                                                   "save_entity_state_payload_promotable_no_token.json"
                                                 )
  @payload_save_entity_state_promotable read_json("save_entity_state_payload_promotable.json")
  @payload_save_entity_state_unpromotable read_json("save_entity_state_payload_unpromotable.json")
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

    test "save_entity_state succeeds if no promotion keys are provided", %{
      socket: socket,
      hub: hub,
      account: account
    } do
      %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()
      temp_file = generate_temp_file("test")

      {:ok, _, socket} =
        subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

      {:ok, uuid} = Storage.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")

      updated_map =
        @payload_save_entity_state_promotable_no_token
        |> Map.put("file_id", uuid)
        |> Map.put("file_access_token", "secret")

      assert_reply push(socket, "save_entity_state", updated_map), :ok
    end

    test "save_entity_state succeeds if provided correct promotion keys", %{
      socket: socket,
      hub: hub,
      account: account
    } do
      %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()
      temp_file = generate_temp_file("test")

      {:ok, _, socket} =
        subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

      {:ok, uuid} = Storage.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")

      updated_map =
        @payload_save_entity_state_promotable
        |> Map.put("file_id", uuid)
        |> Map.put("file_access_token", "secret")

      assert_reply push(socket, "save_entity_state", updated_map), :ok
    end

    test "save_entity_state fails if provided incorrect promotion parameters", %{
      socket: socket,
      hub: hub,
      account: account
    } do
      %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()
      temp_file = generate_temp_file("test2")

      {:ok, _, socket} =
        subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

      {:ok, uuid} = Storage.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")

      updated_map =
        @payload_save_entity_state_unpromotable
        |> Map.put("file_id", uuid)
        |> Map.put("file_access_token", " not_secret")

      assert_reply push(socket, "save_entity_state", updated_map),
                   :error,
                   %{
                     reason: :not_allowed
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

  test "delete_entity_state replies with error if owned file does not exist", %{
    socket: socket,
    hub: hub,
    account: account
  } do
    %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()

    {:ok, _, socket} =
      subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

    push(socket, "save_entity_state", @payload_save_entity_state)

    non_existent_file_payload =
      Map.put(@payload_delete_entity_state, "file_id", "non_existent_file_id")

    assert_reply push(socket, "delete_entity_state", non_existent_file_payload), :error, %{
      reason: :file_not_found
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

  test "delete_entity_state deletes the entity and deactivates the owned file if file_id is present",
       %{
         socket: socket,
         hub: hub,
         account: account,
         owned_file: owned_file
       } do
    %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()

    {:ok, _, socket} =
      subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

    push(socket, "save_entity_state", @payload_save_entity_state)

    payload_with_file_id =
      Map.put(@payload_delete_entity_state, "file_id", owned_file.owned_file_uuid)

    assert_reply push(socket, "delete_entity_state", payload_with_file_id), :ok

    updated_file = owned_file |> Repo.reload()
    assert updated_file.state == :inactive
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
