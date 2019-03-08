defmodule RetWeb.Api.V1.HubView do
  use RetWeb, :view
  alias Ret.{Hub, Scene, SceneListing}

  def render("create.json", %{hub: hub}) do
    %{
      status: :ok,
      hub_id: hub.hub_sid,
      url: hub |> Hub.url_for()
    }
  end

  def render("show.json", %{hub: %Hub{scene: %Scene{}} = hub}) do
    hub |> render_with_scene
  end

  def render("show.json", %{hub: %Hub{scene_listing: %SceneListing{}} = hub}) do
    hub |> render_with_scene
  end

  # DEPRECATED
  def render("show.json", %{hub: hub}) do
    hub |> render_with_scene_asset(:gltf_bundle, hub.default_environment_gltf_bundle_url)
  end

  def render_with_scene(hub) do
    %{
      hubs: [
        %{
          hub_id: hub.hub_sid,
          name: hub.name,
          slug: hub.slug,
          entry_code: hub.entry_code,
          host: hub.host,
          scene: RetWeb.Api.V1.SceneView.render_scene(hub.scene || hub.scene_listing)
        }
      ]
    }
  end

  # DEPRECATED
  defp render_with_scene_asset(hub, asset_type, asset_url) do
    %{
      hubs: [
        %{
          hub_id: hub.hub_sid,
          name: hub.name,
          slug: hub.slug,
          entry_code: hub.entry_code,
          host: hub.host,
          hub_bindings: hub.hub_bindings |> Enum.map(&Map.take(&1, [:type, :community_id, :channel_id])),
          topics: [
            %{
              topic_id: "#{hub.hub_sid}/#{hub.slug}",
              janus_room_id: Hub.janus_room_id_for_hub(hub),
              assets: [%{asset_type: asset_type, src: asset_url}]
            }
          ]
        }
      ]
    }
  end
end
