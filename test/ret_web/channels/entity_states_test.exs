defmodule RetWeb.EntityStatesTest do
  # use RetWeb.ChannelCase
  # import Ret.TestHelpers

  # alias RetWeb.{Presence, SessionSocket}
  # alias Ret.{AppConfig, Account, Repo, Hub, HubInvite, HubRoleMembership}

  # @default_join_params %{"profile" => %{}, "context" => %{}}

  # setup [:create_account, :create_owned_file, :create_scene, :create_hub, :create_account]

  # setup do
  #   {:ok, socket} = connect(SessionSocket, %{})
  #   {:ok, socket: socket}
  # end

  # @root_save_entity_state_payload Poison.Parser.parse!(
  #                                   '{"root_nid":"vzyk7o2","nid":"vzyk7o2","message":{"version":1,"creates":[["vzyk7o2","media",{"src":"https://scholar.harvard.edu/files/mickens/files/thenightwatch.pdf","recenter":true,"resize":true,"animateLoad":true,"isObjectMenuTarget":true,"sphericalProjection":false}]],"updates":[{"nid":"vzyk7o2","lastOwnerTime":3686968529,"timestamp":3686968494,"owner":"605dece0-f0cd-4047-886d-b8fcebfd573b","creator":"reticulum","data":{"networked-transform":{"version":1,"data":{"position":[13.918883323669434,0.9200000166893005,1.2127301692962646],"rotation":[0,0.7071067094802856,0,0.7071068286895752],"scale":[1,1,1]}}}}],"deletes":[]}}'
  #                                 )
  # @root2_save_entity_state_payload Poison.Parser.parse!(
  #                                    '{"root_nid":"vzyk7o2","nid":"vzyk7o2","message":{"version":1,"creates":[["vzyk7o2","media",{"src":"https://scholar.harvard.edu/files/mickens/files/thenightwatch.pdf","recenter":true,"resize":true,"animateLoad":true,"isObjectMenuTarget":true,"sphericalProjection":false}]],"updates":[{"nid":"vzyk7o2","lastOwnerTime":3686968529,"timestamp":3686968494,"owner":"605dece0-f0cd-4047-886d-b8fcebfd573b","creator":"reticulum","data":{"networked-transform":{"version":1,"data":{"position":[0.0,0.0,0.0],"rotation":[0,0.7071067094802856,0,0.7071068286895752],"scale":[1,1,1]}}}}],"deletes":[]}}'
  #                                  )
  # @child_save_entity_state_payload Poison.Parser.parse!(
  #                                    '{"root_nid":"vzyk7o2","nid":"vzyk7o2.0","message":{"version":1,"creates":[],"updates":[{"nid":"vzyk7o2.0","lastOwnerTime":3686968530,"timestamp":0,"owner":"605dece0-f0cd-4047-886d-b8fcebfd573b","creator":"reticulum","data":{"networked-pdf":{"version":1,"data":{"page":1}}}}],"deletes":[]}}'
  #                                  )

  # @other_save_entity_state_payload Poison.Parser.parse!(
  #                                    '{"root_nid":"abcdef","nid":"abcdef","message":{"version":1,"creates":[["abcdef","media",{"src":"https://scholar.harvard.edu/files/mickens/files/thenightwatch.pdf","recenter":true,"resize":true,"animateLoad":true,"isObjectMenuTarget":true,"sphericalProjection":false}]],"updates":[{"nid":"abcdef","lastOwnerTime":3686968529,"timestamp":3686968494,"owner":"605dece0-f0cd-4047-886d-b8fcebfd573b","creator":"reticulum","data":{"networked-transform":{"version":1,"data":{"position":[13.918883323669434,0.9200000166893005,1.2127301692962646],"rotation":[0,0.7071067094802856,0,0.7071068286895752],"scale":[1,1,1]}}}}],"deletes":[]}}'
  #                                  )
  # @root_delete_entity_state_payload Poison.Parser.parse!(
  #                                     '{"nid":"vzyk7o2","message":{"version":1,"creates":[["vzyk7o2","media",{"animateLoad":true,"isObjectMenuTarget":true,"recenter":true,"resize":true,"sphericalProjection":false,"src":"https://scholar.harvard.edu/files/mickens/files/thenightwatch.pdf"}]],"updates":[{"nid":"vzyk7o2","lastOwnerTime":3688984531,"timestamp":3688317007,"owner":"f21a711b-d223-47db-9ad2-67efdc8b1759","creator":"f21a711b-d223-47db-9ad2-67efdc8b1759","data":{"networked-transform":{"version":1,"data":{"position":[13.918883323669434,0.9200000166893005,1.2127301692962646],"rotation":[0,0.7071067094802856,0,0.7071068286895752],"scale":[1,1,1]}}}}],"deletes":[]}}'
  #                                   )

  # describe "entity states" do
  #   test "list_entity_states", %{socket: socket, hub: hub} do
  #     {:ok, _, socket} = subscribe_and_join(socket, "hub:#{hub.hub_sid}", @default_join_params)

  #     assert_reply push(socket, "list_entity_states", %{}), :ok, %{data: []}
  #   end

  #   test "save_entity_state creates an entity state", %{
  #     socket: socket,
  #     hub: hub,
  #     account: account
  #   } do
  #     %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()

  #     {:ok, _, socket} =
  #       subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

  #     assert_reply push(socket, "save_entity_state", @root_save_entity_state_payload), :ok
  #     assert_reply push(socket, "list_entity_states", %{}), :ok, %{data: [entity_state]}
  #     assert entity_state.root_nid === @root_save_entity_state_payload["root_nid"]
  #     assert entity_state.nid === @root_save_entity_state_payload["nid"]
  #     assert entity_state.message === @root_save_entity_state_payload["message"]
  #   end

  #   test "save_entity_state overwrites previous entity state", %{
  #     socket: socket,
  #     hub: hub,
  #     account: account
  #   } do
  #     %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()

  #     {:ok, _, socket} =
  #       subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

  #     root2_save_entity_state_payload = @root2_save_entity_state_payload
  #     assert_reply push(socket, "save_entity_state", @root_save_entity_state_payload), :ok
  #     assert_reply push(socket, "list_entity_states", %{}), :ok, %{data: [entity_state]}
  #     assert entity_state.message === @root_save_entity_state_payload["message"]
  #     # In particular, inspect the initial entity position
  #     assert Enum.at(entity_state.message["updates"], 0)["data"]["networked-transform"]["data"][
  #              "position"
  #            ] === [13.918883323669434, 0.9200000166893005, 1.2127301692962646]

  #     assert_reply push(socket, "save_entity_state", root2_save_entity_state_payload), :ok
  #     assert_reply push(socket, "list_entity_states", %{}), :ok, %{data: [entity_state]}
  #     assert entity_state.message === root2_save_entity_state_payload["message"]
  #     # In particular, see that the entity position changed
  #     assert Enum.at(entity_state.message["updates"], 0)["data"]["networked-transform"]["data"][
  #              "position"
  #            ] === [0.0, 0.0, 0.0]
  #   end

  #   test "save_entity_state is denied if not logged in", %{
  #     socket: socket,
  #     hub: hub
  #   } do
  #     {:ok, _, socket} = subscribe_and_join(socket, "hub:#{hub.hub_sid}", @default_join_params)

  #     assert_reply push(socket, "save_entity_state", @root_save_entity_state_payload), :error, %{
  #       reason: :not_logged_in
  #     }
  #   end

  #   test "save_entity_state is denied if account lacks pin permissions", %{
  #     socket: socket,
  #     hub: hub,
  #     account: account
  #   } do
  #     {:ok, _, socket} =
  #       subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

  #     assert_reply push(socket, "save_entity_state", @root_save_entity_state_payload), :error, %{
  #       reason: :unauthorized
  #     }
  #   end

  #   test "delete_entity_state deletes the entity state with the matching nid", %{
  #     socket: socket,
  #     hub: hub,
  #     account: account
  #   } do
  #     %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()

  #     {:ok, _, socket} =
  #       subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

  #     assert_reply push(socket, "save_entity_state", @root_save_entity_state_payload), :ok
  #     assert_reply push(socket, "save_entity_state", @child_save_entity_state_payload), :ok
  #     assert_reply push(socket, "delete_entity_state", @root_delete_entity_state_payload), :ok
  #     assert_reply push(socket, "list_entity_states", %{}), :ok, %{data: [entity_state]}

  #     assert entity_state.root_nid === @child_save_entity_state_payload["root_nid"]
  #     assert entity_state.nid === @child_save_entity_state_payload["nid"]
  #     assert entity_state.message === @child_save_entity_state_payload["message"]
  #   end

  #   test "delete_entity_states_for_root_nid deletes all entity states with matching root_nids", %{
  #     socket: socket,
  #     hub: hub,
  #     account: account
  #   } do
  #     %HubRoleMembership{hub: hub, account: account} |> Repo.insert!()

  #     {:ok, _, socket} =
  #       subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params_for_account(account))

  #     assert_reply push(socket, "save_entity_state", @root_save_entity_state_payload), :ok
  #     assert_reply push(socket, "save_entity_state", @child_save_entity_state_payload), :ok
  #     assert_reply push(socket, "save_entity_state", @other_save_entity_state_payload), :ok

  #     assert_reply push(
  #                    socket,
  #                    "delete_entity_states_for_root_nid",
  #                    @root_delete_entity_state_payload
  #                  ),
  #                  :ok

  #     assert_reply push(socket, "list_entity_states", %{}), :ok, %{data: [entity_state]}

  #     assert entity_state.root_nid === @other_save_entity_state_payload["root_nid"]
  #     assert entity_state.nid === @other_save_entity_state_payload["nid"]
  #     assert entity_state.message === @other_save_entity_state_payload["message"]
  #   end
  # end

  # defp join_params_for_hub_invite(%HubInvite{} = hub_invite) do
  #   join_params_for_hub_invite_id(hub_invite.hub_invite_sid)
  # end

  # defp join_params_for_hub_invite_id(hub_invite_id) do
  #   join_params(%{"hub_invite_id" => hub_invite_id})
  # end

  # defp join_params_for_account(account) do
  #   {:ok, token, _params} = account |> Ret.Guardian.encode_and_sign()
  #   join_params(%{"auth_token" => token})
  # end

  # defp join_params(%{} = params) do
  #   Map.merge(@default_join_params, params)
  # end

  # defp join_hub(socket, %Hub{} = hub, params) do
  #   subscribe_and_join(socket, "hub:#{hub.hub_sid}", params)
  # end

  # defp create_invite_only_hub() do
  #   {:ok, hub: hub} = create_hub(%{scene: nil})

  #   hub
  #   |> Ret.Hub.changeset_for_entry_mode(:invite)
  #   |> Ret.Repo.update!()

  #   hub_invite = Ret.HubInvite.find_or_create_invite_for_hub(hub)

  #   %{hub: hub, hub_invite: hub_invite}
  # end
end
