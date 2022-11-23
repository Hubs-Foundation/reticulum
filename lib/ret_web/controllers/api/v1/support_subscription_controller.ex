defmodule RetWeb.Api.V1.SupportSubscriptionController do
  use RetWeb, :controller
  import Ecto.Query

  alias Ret.{Repo, Support, SupportSubscription}
  alias Ret.Repo

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit when action in [:create, :delete])

  # Only allow access with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [:create, :delete])

  def index(conn, _params) do
    case Support.available?() do
      true -> conn |> send_resp(200, "OK")
      false -> conn |> send_resp(404, "Unavailable")
    end
  end

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
    Repo.delete_all(from SupportSubscription, where: [identifier: ^identifier])
    conn |> send_resp(200, "OK")
  end
end
