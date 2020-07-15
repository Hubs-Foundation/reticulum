# TODO: Should this API be re-using code in media_search.ex?
# TODO: Resolve this question before deploy
defmodule Ret.RoomSearchResult do
  # TODO: Should :data be called :entries like Ret.MediaSearchResult and the scrivener api?
  # TODO: Should :data be called :rooms because that's "what is being returned"
  # TODO: Resolve this question before deploy
  @enforce_keys [:meta, :data]
  @derive {Jason.Encoder, only: [:meta, :data, :suggestions]}
  defstruct [:meta, :data, :suggestions]
end

defmodule Ret.RoomSearchResultMeta do
  # TODO: Should :source exist and be set to "rooms" like Ret.MedaiSearchResultMeta
  # TODO: Resolve this question before deploy
  @derive {Jason.Encoder, only: [:next_cursor]}
  defstruct [:next_cursor]
end

defmodule RetWeb.Api.V1.RoomController do
  use RetWeb, :controller
  import RetWeb.ApiHelpers, only: [exec_api_show: 4]
  @page_size 24

  import Ecto.Query
  alias Ret.{Hub, Repo}

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

  defp paginate(query, page, size) do
    from(query,
      limit: ^size,
      offset: ^((page - 1) * size)
    )
  end

  defp render_hub_records(conn, params) do
    account = Guardian.Plug.current_resource(conn)
    page_number = (params["cursor"] || "1") |> to_string |> Integer.parse() |> elem(0)

    conditions =
      false
      |> include_public_rooms()
      |> maybe_include_created_rooms(account)
      |> maybe_include_favorite_rooms(account)

    query =
      Hub
      |> maybe_join_favorites(account)
      |> where([_hub, _favorite], ^conditions)
      |> filter_by_entry_mode("allow")
      |> maybe_filter_by_only_favorites(params)
      |> maybe_filter_by_room_ids(params)

    results =
      query
      |> Ret.Repo.paginate(%{page: page_number, page_size: @page_size})
      |> result_for_page(page_number)

    {:ok, {200, results}}
  end

  defp include_public_rooms(conditions) do
    dynamic([hub], hub.allow_promotion or ^conditions)
  end

  defp maybe_include_favorite_rooms(conditions, %Ret.Account{} = account) do
    dynamic([hub, favorite], not is_nil(favorite) or ^conditions)
  end

  defp maybe_include_favorite_rooms(conditions, _account) do
    conditions
  end

  defp maybe_include_created_rooms(conditions, %Ret.Account{} = account) do
    dynamic([hub], hub.created_by_account_id == ^account.account_id or ^conditions)
  end

  defp maybe_include_created_rooms(conditions, _account) do
    conditions
  end

  def maybe_join_favorites(query, %Ret.Account{} = account) do
    query
    |> join(:left, [h], f in Ret.AccountFavorite, on: f.hub_id == h.hub_id and f.account_id == ^account.account_id)
  end

  def maybe_join_favorites(query, _account) do
    query
  end

  def filter_by_favorite(query) do
    query
    |> where([hub, favorite], not is_nil(favorite))
  end

  def filter_by_entry_mode(query, entry_mode) do
    query
    |> where([_hub], ^[entry_mode: entry_mode])
  end

  defp maybe_filter_by_room_ids(query, %{"room_ids" => room_ids}) when is_list(room_ids) do
    query |> where([hub], hub.hub_sid in ^room_ids)
  end

  defp maybe_filter_by_room_ids(query, _params) do
    query
  end

  defp maybe_filter_by_only_favorites(query, %{"only_favorites" => "true"}) do
    query |> filter_by_favorite()
  end

  defp maybe_filter_by_only_favorites(query, %{"only_favorites" => true}) do
    query |> filter_by_favorite()
  end

  defp maybe_filter_by_only_favorites(query, _params) do
    query
  end

  defp result_for_page(page, page_number) do
    %Ret.RoomSearchResult{
      meta: %Ret.RoomSearchResultMeta{
        next_cursor:
          if page.total_pages > page_number do
            page_number + 1
          else
            nil
          end
      },
      # TODO: Should data be called entries like the scrivener api
      data:
        page.entries
        |> Enum.map(fn hub ->
          Phoenix.View.render(RetWeb.Api.V1.RoomView, "show.json", %{hub: hub})
        end)
    }
  end
end
