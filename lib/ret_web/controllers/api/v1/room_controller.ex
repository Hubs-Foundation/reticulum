defmodule Ret.RoomSearchResult do
  @enforce_keys [:meta, :data]
  @derive {Jason.Encoder, only: [:meta, :data]}
  defstruct [:meta, :data]
end

defmodule Ret.RoomSearchResultMeta do
  @derive {Jason.Encoder, only: [:next_cursor, :total_pages]}
  defstruct [:next_cursor, :total_pages]
end

defmodule RetWeb.Api.V1.RoomController do
  use RetWeb, :controller
  import RetWeb.ApiHelpers, only: [exec_api_show: 4]
  @page_size 24

  import Ret.RoomQueryHelpers
  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  # Only allow access to remove hubs with secret header
  plug(RetWeb.Plugs.HeaderAuthorization when action in [:delete])

  @show_request_schema %{
                         "type" => "object",
                         "properties" => %{
                           "ids" => %{
                             "type" => "array",
                             "items" => %{
                               "type" => "string"
                             }
                           },
                           "favorites" => %{
                             "type" => "boolean"
                           },
                           "created" => %{
                             "type" => "boolean"
                           },
                           "public" => %{
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
    page_number = (params["cursor"] || "1") |> to_string |> Integer.parse() |> elem(0)

    results =
      build_rooms_query(account, params)
      |> Ret.Repo.paginate(%{page: page_number, page_size: @page_size})
      |> result_for_page(page_number)

    {:ok, {200, results}}
  end

  defp result_for_page(page, page_number) do
    %Ret.RoomSearchResult{
      meta: %Ret.RoomSearchResultMeta{
        next_cursor:
          if page.total_pages > page_number do
            page_number + 1
          else
            nil
          end,
        total_pages: page.total_pages
      },
      data:
        page.entries
        |> Enum.map(fn hub ->
          Phoenix.View.render(RetWeb.Api.V1.RoomView, "show.json", %{hub: hub})
        end)
    }
  end
end
