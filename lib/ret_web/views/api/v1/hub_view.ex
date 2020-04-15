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

  def render("show.json", %{hub: %Hub{scene: %Scene{}} = hub, embeddable: embeddable} = params) do
    hub |> render_with_scene(embeddable, params[:account])
  end

  def render("show.json", %{hub: %Hub{scene_listing: %SceneListing{}} = hub, embeddable: embeddable} = params) do
    hub |> render_with_scene(embeddable, params[:account])
  end

  def render("show.json", %{hub: hub}) do
    hub |> render_with_scene_asset(:gltf_bundle, hub.default_environment_gltf_bundle_url)
  end

  defp render_with_scene(hub, embeddable, account) do
    %{
      hubs: [
        %{
          hub_id: hub.hub_sid,
          name: hub.name,
          description: hub.description,
          user_data: hub.user_data,
          slug: hub.slug,
          allow_promotion: hub.allow_promotion,
          entry_code: hub.entry_code,
          entry_mode: hub.entry_mode,
          host: hub.host,
          port: janus_port(),
          scene: RetWeb.Api.V1.SceneView.render_scene(hub.scene || hub.scene_listing, account),
          embed_token:
            if embeddable do
              hub.embed_token
            else
              nil
            end,
          member_permissions: hub |> Hub.member_permissions_for_hub(),
          room_size: hub |> Hub.room_size_for(),
          member_count: hub |> Hub.member_count_for(),
          lobby_count: hub |> Hub.lobby_count_for()
        }
      ]
    }
  end

  defp render_with_scene_asset(hub, asset_type, asset_url) do
    %{
      hubs: [
        %{
          hub_id: hub.hub_sid,
          name: hub.name,
          description: hub.description,
          user_data: hub.user_data,
          slug: hub.slug,
          allow_promotion: hub.allow_promotion,
          entry_code: hub.entry_code,
          entry_mode: hub.entry_mode,
          host: hub.host,
          port: janus_port(),
          turn: turn_info(),
          topics: [
            %{
              topic_id: "#{hub.hub_sid}/#{hub.slug}",
              janus_room_id: Hub.janus_room_id_for_hub(hub),
              assets: [%{asset_type: asset_type, src: asset_url}]
            }
          ],
          member_permissions: hub |> Hub.member_permissions_for_hub(),
          room_size: hub |> Hub.room_size_for(),
          member_count: hub |> Hub.member_count_for(),
          lobby_count: hub |> Hub.lobby_count_for()
        }
      ]
    }
  end

  defp janus_port do
    Application.get_env(:ret, Ret.JanusLoadStatus)[:janus_port]
  end

  defp turn_transports do
    (Application.get_env(:ret, Ret.Coturn)[:public_tls_ports] || "5349")
    |> String.split(",")
    |> Enum.map(&%{transport: :tls, port: &1 |> Integer.parse() |> elem(0)})
  end

  defp turn_info do
    if Ret.Coturn.enabled?() do
      {username, credential} = Ret.Coturn.generate_credentials()
      transports = turn_transports()
      %{enabled: true, username: username, credential: credential, transports: transports}
    else
      %{enabled: false}
    end
  end
end
