defmodule RetWeb.Api.V1.HubView do
  use RetWeb, :view
  alias Ret.Hub

  def render("create.json", %{ hub: hub }) do
    %{ 
      status: :ok, 
      hub_id: hub.hub_sid,
      url: "#{RetWeb.Endpoint.url}/#{hub.hub_sid}/#{hub.slug}"
    }
  end

  def render("show.json", %{ hub: hub }) do
    %{
      hubs: [
        %{
          hub_id: hub.hub_sid,
          channels: [
            %{
              channel_media: [:space],
              channel_id: "#{hub.hub_sid}/#{hub.slug}",
              janus_room_id: Hub.janus_room_id_for_hub(hub),
              attributes: [["default-space"]],
              assets: [
                %{ asset_type: :gltf_bundle, src: hub.default_environment_gltf_bundle_url }
              ]
            }
          ]
        }
      ]
    }
  end
end
