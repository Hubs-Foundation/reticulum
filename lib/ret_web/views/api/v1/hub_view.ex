defmodule RetWeb.Api.V1.HubView do
  use RetWeb, :view
  alias Ret.{Hub, Scene, SceneListing}

  def render("create.json", %{hub: hub}) do
    %{
      status: :ok,
      hub_id: hub.hub_sid,
      url: hub |> Hub.url_for(),
      creator_assignment_token: hub.creator_assignment_token,
      embed_token: hub.embed_token
    }
  end

  def render("show.json", %{hub: %Hub{scene: %Scene{}} = hub, embeddable: embeddable}) do
    hub |> render_with_scene(embeddable)
  end

  def render("show.json", %{hub: %Hub{scene_listing: %SceneListing{}} = hub, embeddable: embeddable}) do
    hub |> render_with_scene(embeddable)
  end

  # DEPRECATED
  def render("show.json", %{hub: hub}) do
    hub |> render_with_scene_asset(:gltf_bundle, hub.default_environment_gltf_bundle_url)
  end

  def render_with_scene(hub, embeddable) do
    %{
      hubs: [
        %{
          hub_id: hub.hub_sid,
          name: hub.name,
          slug: hub.slug,
          entry_code: hub.entry_code,
          entry_mode: hub.entry_mode,
          host: hub.host,
          scene: RetWeb.Api.V1.SceneView.render_scene(hub.scene || hub.scene_listing),
          embed_token:
            if embeddable do
              hub.embed_token
            else
              nil
            end,
          perms: hub |> Hub.perms_for_hub()
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
          entry_mode: hub.entry_mode,
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
