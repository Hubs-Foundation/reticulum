defmodule RetWeb.Api.V1.HubView do
  use RetWeb, :view
  alias Ret.Hub

  def render("create.json", %{ hub: hub }) do
    %{ 
      status: :ok, 
      url: "#{RetWeb.Router.Helpers.api_v1_hub_url(RetWeb.Endpoint, :show, hub.hub_sid)}"
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
              channel_id: "#{hub.hub_sid}/home",
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
