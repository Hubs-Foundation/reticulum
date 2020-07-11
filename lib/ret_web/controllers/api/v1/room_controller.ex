defmodule RetWeb.Api.V1.RoomController do
  use RetWeb, :controller
  import RetWeb.ApiHelpers

  alias Ret.{Account, AccountFavorite, Hub, Scene, SceneListing, Repo}

  import Canada, only: [can?: 2]
  import Ecto.Query, only: [where: 3, preload: 2, join: 5]

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  # Only allow access to remove hubs with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [:delete])

  @show_request_schema %{
                         "type" => "object",
                         "properties" => %{
                           "room_ids" => %{
                             "type" => "array",
                             "items" => %{
                               "type" => "string"
                             },
                             "only_favorites" => %{
                               "type" => "bool"
                             }
                           }
                         }
                       }
                       |> ExJsonSchema.Schema.resolve()

  def index(conn, params) do
    exec_api_show(conn, params, @show_request_schema, &render_hub_records/2)
  end

  defp render_hub_records(conn, params) do
    account = Guardian.Plug.current_resource(conn)

    favorited_rooms =
      hub_query(account, params)
      |> filter_by_favorite(account)
      |> Ret.Repo.all()

    created_by_account_rooms =
      hub_query(account, params)
      |> filter_by_created_by_account(account)
      |> Ret.Repo.all()

    public_rooms =
      hub_query(account, params)
      |> filter_by_allow_promotion(true)
      |> Ret.Repo.all()

    rooms = (favorited_rooms ++ created_by_account_rooms ++ public_rooms) |> Enum.uniq_by(fn room -> room.hub_sid end)

    results =
      rooms
      |> Enum.map(fn hub ->
        Phoenix.View.render(RetWeb.Api.V1.RoomView, "show.json", %{hub: hub})
      end)

    {:ok, {200, results}}
  end

  defp filter_by_created_by_account(query, %Account{} = account) do
    query
    |> preload(:created_by_account)
    |> where([hub], hub.created_by_account_id == ^account.account_id)
  end

  defp filter_by_created_by_account(query, _params) do
    query
    |> ensure_query_returns_no_results
  end

  defp maybe_filter_by_room_ids(query, %{"room_ids" => room_ids}) do
    query |> maybe_filter_by_room_ids(room_ids)
  end

  defp maybe_filter_by_room_ids(query, room_ids) when is_list(room_ids) do
    query |> where([hub], hub.hub_sid in ^room_ids)
  end

  defp maybe_filter_by_room_ids(query, _params) do
    query
  end

  defp maybe_filter_by_only_favorites(query, account, %{"only_favorites" => "true"}) do
    query |> filter_by_favorite(account)
  end

  defp maybe_filter_by_only_favorites(query, account, %{"only_favorites" => true}) do
    query |> filter_by_favorite(account)
  end

  defp maybe_filter_by_only_favorites(query, _, _) do
    query
  end

  defp filter_by_entry_mode(query, mode) do
    query
    |> where([_], ^[entry_mode: mode])
  end

  defp filter_by_allow_promotion(query, allow) do
    query
    |> where([_], ^[allow_promotion: allow])
  end

  defp filter_by_favorite(query, %Account{} = account) do
    query
    |> join(:inner, [h], f in AccountFavorite, on: f.hub_id == h.hub_id and f.account_id == ^account.account_id)
  end

  defp filter_by_favorite(query, _) do
    query
    |> ensure_query_returns_no_results
  end

  defp ensure_query_returns_no_results(query) do
    query
    |> where([_], false)
  end

  defp hub_query(account, params) do
    Ret.Hub
    |> filter_by_entry_mode("allow")
    |> maybe_filter_by_room_ids(params)
    |> maybe_filter_by_only_favorites(account, params)
  end


end
