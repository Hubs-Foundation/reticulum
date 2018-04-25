defmodule RetWeb.PageController do
  use RetWeb, :controller
  alias Ret.{Repo, Hub}

  # Split the HTML file into two parts, on the line that contains HUB_META_TAGS, so we can add meta tags
  @hub_html_chunks "#{Application.app_dir(:ret)}/priv/static/hub.html"
                   |> File.read!()
                   |> String.split("\n")
                   |> Enum.split_while(&(!Regex.match?(~r/HUB_META_TAGS/, &1)))
                   |> Tuple.to_list()

  def call(conn, _params) do
    render_for_path(conn.request_path, conn)
  end

  def render_for_path("/", conn) do
    render_file(conn, "#{get_file_prefix(conn)}index.html")
  end

  def render_for_path(path, conn) do
    hub_sid =
      path
      |> String.split("/")
      |> Enum.at(1)

    hub = Hub |> Repo.get_by(hub_sid: hub_sid)
    hub_meta_tags = Phoenix.View.render_to_string(RetWeb.PageView, "hub-meta.html", hub: hub)

    body = List.insert_at(@hub_html_chunks, 1, hub_meta_tags)
    conn |> send_resp(200, body)
  end

  defp get_file_prefix(conn) do
    if conn.host =~ "smoke" do
      "smoke-"
    else
      ""
    end
  end

  defp render_file(conn, file) do
    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> Plug.Conn.send_file(200, "#{Application.app_dir(:ret)}/priv/static/#{file}")
  end
end
