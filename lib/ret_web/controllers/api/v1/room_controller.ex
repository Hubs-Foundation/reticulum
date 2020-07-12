defmodule RetWeb.Api.V1.RoomController do
  use RetWeb, :controller
  import RetWeb.ApiHelpers, only: [exec_api_show: 4]

  require Ecto.Query
  alias Ret.{Hub}

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
                             }
                           },
                           "only_favorites" => %{
                             "type" => "boolean"
                           }
                         }
                       }
                       |> ExJsonSchema.Schema.resolve()

  def index(conn, params) do
    exec_api_show(conn, params, @show_request_schema, &render_hub_records/2)
  end

  defp render_hub_records(conn, params) do
    account = Guardian.Plug.current_resource(conn)

    public_rooms =
      Hub
      |> filter_by_allow_promotion(true)

    created_rooms =
      Hub
      |> filter_by_creator(account)

    favorite_rooms =
      Hub
      |> filter_by_favorite(account)

    results =
      public_rooms
      |> Ecto.Query.union(^created_rooms)
      |> Ecto.Query.union(^favorite_rooms)
      |> filter_by_entry_mode("allow")
      |> maybe_filter_by_room_ids(params)
      |> maybe_filter_by_only_favorites(account, params)
      |> Ret.Repo.all()
      |> Enum.map(fn hub ->
        Phoenix.View.render(RetWeb.Api.V1.RoomView, "show.json", %{hub: hub})
      end)

    {:ok, {200, results}}
  end

  def filter_by_favorite(query, %Ret.Account{} = account) do
    query
    |> Ecto.Query.join(:inner, [h], f in Ret.AccountFavorite,
      on: f.hub_id == h.hub_id and f.account_id == ^account.account_id
    )
  end

  def filter_by_favorite(query, _account) do
    query
    |> ensure_query_returns_no_results()
  end

  def filter_by_creator(query, %Ret.Account{} = account) do
    query
    |> Ecto.Query.where([hub], hub.created_by_account_id == ^account.account_id)
  end

  def filter_by_creator(query, _account) do
    query
    |> ensure_query_returns_no_results()
  end

  def filter_by_allow_promotion(query, allow) do
    query
    |> Ecto.Query.where([_], ^[allow_promotion: allow])
  end

  def filter_by_entry_mode(query, entry_mode) do
    query
    |> Ecto.Query.where([_], ^[entry_mode: entry_mode])
  end

  defp maybe_filter_by_room_ids(query, %{"room_ids" => room_ids}) do
    query |> maybe_filter_by_room_ids(room_ids)
  end

  defp maybe_filter_by_room_ids(query, room_ids) when is_list(room_ids) do
    query |> Ecto.Query.where([hub], hub.hub_sid in ^room_ids)
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

  defp maybe_filter_by_only_favorites(query, _account, _params) do
    query
  end

  # defp filter_by_entry_mode(query, mode) do
  #   query
  #   |> where([_], ^[entry_mode: mode])
  # end

  # defp filter_by_allow_promotion(query, allow) do
  #   query
  #   |> where([_], ^[allow_promotion: allow])
  # end

  # defp filter_by_favorite(query, %Account{} = account) do
  #   query
  #   |> join(:inner, [h], f in AccountFavorite, on: f.hub_id == h.hub_id and f.account_id == ^account.account_id)
  # end

  # defp filter_by_favorite(query, _) do
  #   query
  #   |> ensure_query_returns_no_results
  # end

  defp ensure_query_returns_no_results(query) do
    query
    |> Ecto.Query.where([_], false)
  end
end
