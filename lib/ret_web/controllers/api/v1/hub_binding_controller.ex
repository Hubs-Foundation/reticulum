defmodule RetWeb.Api.V1.HubBindingController do
  use RetWeb, :controller

  alias Ret.{HubBinding, Repo}

  def create(
        conn,
        %{"hub_binding" => %{"hub_id" => _, "type" => _, "community_id" => community_id, "channel_id" => channel_id}} =
          params
      ) do
    hub_binding = HubBinding |> Repo.get_by(community_id: community_id, channel_id: channel_id)

    {result, _} =
      (hub_binding || %HubBinding{})
      |> HubBinding.changeset(params["hub_binding"])
      |> Repo.insert_or_update()

    case result do
      :ok -> conn |> send_resp(201, "created binding")
      :error -> conn |> send_resp(422, "invalid binding")
    end
  end

  def bind_hub(%{"community_id" => community_id, "channel_id" => channel_id, "type" => _, "hub_id" => _} = params) do
    hub_binding = HubBinding |> Repo.get_by(community_id: community_id, channel_id: channel_id)

    IO.inspect(params)
    {result, _} =
      (hub_binding || %HubBinding{})
      |> HubBinding.changeset(params)
      |> Repo.insert_or_update()
  end

end

