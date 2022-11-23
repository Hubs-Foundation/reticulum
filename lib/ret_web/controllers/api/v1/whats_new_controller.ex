defmodule RetWeb.Api.V1.WhatsNewController do
  use RetWeb, :controller

  @endpoint "https://api.github.com/graphql"
  @per_page 20
  @paragraph_separator "\r\n\r\n"
  @image_prefix "!["
  @whats_new_label "whats new"

  def show(conn, params) do
    {_status, pull_requests} = Cachex.fetch(:whats_new, [params["source"], params["cursor"]])

    last_pull_request = Enum.at(pull_requests, -1, %{})
    has_more = Enum.count(pull_requests) === @per_page

    conn
    |> json(%{
      pullRequests: Enum.map(pull_requests, &format_pull_request/1),
      moreCursor: if(has_more, do: last_pull_request["cursor"], else: nil)
    })
  end

  def fetch_pull_requests([source, cursor]) do
    {:commit, fetch_pull_requests(source, cursor, module_config(:token))}
  end

  defp fetch_pull_requests(_source, _cursor, nil = _token),
    do: []

  defp fetch_pull_requests(_source, _cursor, "" = _token),
    do: []

  defp fetch_pull_requests("hubs" = _source, cursor, token),
    do: fetch_pull_requests("mozilla", "hubs", cursor, token)

  defp fetch_pull_requests("spoke" = _source, cursor, token),
    do: fetch_pull_requests("mozilla", "spoke", cursor, token)

  defp fetch_pull_requests(_source, _cursor, _token),
    do: []

  defp fetch_pull_requests(repo_owner, repo_name, cursor, token) do
    query = "
      query {
        repository(owner: \"#{repo_owner}\", name: \"#{repo_name}\") {
          pullRequests(
            labels: [\"#{@whats_new_label}\"],
            states: [MERGED],
            first: #{@per_page},
            orderBy: { field: CREATED_AT, direction: DESC },
            #{if(cursor, do: "after: \"#{cursor}\"", else: "")}
          ) {
            edges {
              node {
                title
                url
                mergedAt
                body
              }
              cursor
            }
          }
        }
      }
    "

    %{body: resp_body} =
      Ret.HttpUtils.retry_post_until_success(
        @endpoint,
        %{query: query} |> Poison.encode!(),
        headers: [{"authorization", "token #{token}"}]
      )

    resp_body |> Poison.decode() |> extract_pull_requests
  end

  defp extract_pull_requests({:ok, %{"data" => data}}),
    do: data["repository"]["pullRequests"]["edges"]

  defp extract_pull_requests(_), do: []

  defp format_pull_request(%{"node" => pull_request}) do
    body = pull_request["body"]

    paragraphs = String.split(body, @paragraph_separator)

    para1 = Enum.at(paragraphs, 0)
    para2 = Enum.at(paragraphs, 1)

    formatted_body =
      if para2 && String.contains?(para2, @image_prefix) do
        Enum.join([para1, para2], @paragraph_separator)
      else
        para1
      end

    pull_request |> Map.put("body", formatted_body)
  end

  defp module_config(key), do: Application.get_env(:ret, __MODULE__)[key]
end
