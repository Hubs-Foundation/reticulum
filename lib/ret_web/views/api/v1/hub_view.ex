defmodule RetWeb.Api.V1.HubView do
  use RetWeb, :view
  alias Ret.{Hub, Scene}

  def render("create.json", %{hub: hub}) do
    %{
      status: :ok,
      hub_id: hub.hub_sid,
      url: hub |> Hub.url_for()
    }
  end

  def render("show.json", %{hub: %Hub{scene: %Scene{}} = hub}) do
    %{
      hubs: [
        %{
          hub_id: hub.hub_sid,
          name: hub.name,
          entry_code: hub.entry_code,
          host: hub.host,
          room_id: Hub.janus_room_id_for_hub(hub),
          scene: RetWeb.Api.V1.SceneView.render_scene(hub.scene)
        }
      ]
    }
  end

  # DEPRECATED
  def render("show.json", %{hub: hub}) do
    hub |> render_with_scene_asset(:gltf_bundle, hub.default_environment_gltf_bundle_url)
  end

  # DEPRECATED
  defp render_with_scene_asset(hub, asset_type, asset_url) do
    %{
      hubs: [
        %{
          hub_id: hub.hub_sid,
          name: hub.name,
          entry_code: hub.entry_code,
          host: hub.host,
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
