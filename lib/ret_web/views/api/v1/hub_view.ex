defmodule RetWeb.Api.V1.HubView do
  use RetWeb, :view
  alias Ret.Hub

  def render("show.json", %{ hub: hub }) do
    %{
      hubs: [
        %{
          hub_id: hub.hub_sid,
          channels: [
            %{
              channel_media: [:space],
              channel_id: "#{hub.hub_sid}/home",
              janus_sfu_room: Hub.janus_sfu_room_for_hub(hub),
              attributes: [["default-space"]],
              assets: [
                %{ asset_type: :gltf_bundle, url: hub.default_environment_gltf_bundle_url }
              ]
            }
          ]
        }
      ]
    }
  end
end
