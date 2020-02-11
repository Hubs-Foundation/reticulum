defmodule RetWeb.AuthChannelTest do
  use RetWeb.ChannelCase
  import Ret.TestHelpers

  alias RetWeb.{SessionSocket}
  alias Ret.{AppConfig, Repo, Hub}

  setup [:create_account, :create_owned_file, :create_scene]

  setup do
    {:ok, socket} = connect(SessionSocket, %{})
    {:ok, socket: socket}
  end

  test "joining hub works", %{socket: socket, scene: scene} do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()
    {:ok, %{session_id: _session_id}, _socket} = subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params())
  end

  test "joining hub does not work if sign in required", %{socket: socket, scene: scene} do
    AppConfig.set_config_value("features|require_account_for_join", true)
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()
    {:error, _reason} = subscribe_and_join(socket, "hub:#{hub.hub_sid}", join_params())
    AppConfig.set_config_value("features|require_account_for_join", false)
  end

  defp join_params do
    %{"profile" => %{}, "context" => %{}}
  end
end
