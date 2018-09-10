defmodule RetWeb.Api.V1.SupportSubscriptionController do
  use RetWeb, :controller
  import Ecto.Query

  alias Ret.{Repo, SupportSubscription}
  alias Ret.Repo

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  # Only allow access with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [])

  def create(conn, %{"subscription" => %{"identifier" => identifier}}) do
    with %SupportSubscription{} <- SupportSubscription |> Repo.get_by(identifier: identifier) do
      conn |> send_resp(200, "OK")
    else
      _ ->
        {result, _subscription} =
          %SupportSubscription{}
          |> SupportSubscription.changeset(%{identifier: identifier})
          |> Repo.insert()

        case result do
          :ok -> conn |> send_resp(200, "OK")
          :error -> conn |> send_resp(422, "error")
        end
    end
  end

  def delete(conn, %{"id" => identifier}) do
    SupportSubscription
    |> where(identifier: ^identifier)
    |> Repo.delete_all()

    conn |> send_resp(200, "OK")
  end
end
