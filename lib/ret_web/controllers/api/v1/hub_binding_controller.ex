defmodule RetWeb.Api.V1.HubBindingController do
  use RetWeb, :controller

  alias Ret.{HubBinding}

  def create(
        conn,
        %{"hub_binding" => %{"hub_id" => _, "type" => _, "community_id" => _, "channel_id" => _}} =
          params
      ) do
    {result, _} = HubBinding.bind_hub(params["hub_binding"])

    case result do
      :ok -> conn |> send_resp(201, "created binding")
      :error -> conn |> send_resp(422, "invalid binding")
    end
  end
end
