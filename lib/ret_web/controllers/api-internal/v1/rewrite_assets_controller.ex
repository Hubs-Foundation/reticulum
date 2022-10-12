defmodule RetWeb.ApiInternal.V1.RewriteAssetsController do
  use RetWeb, :controller

  alias Ret.{RoomObject, Project, Scene}

  @starts_with_https ~r/^https:\/\//
  def post(conn, %{"old_domain" => old_domain, "new_domain" => new_domain})
      when is_binary(old_domain) and is_binary(new_domain) do
    conn = put_resp_header(conn, "content-type", "application/json")

    # TODO HACK We're retrieving and manipulating a lot of records and files here, which is pretty ineffiecient.
    # We should instead try to avoid baking the domain into these assets in the first place.

    with false <- is_empty_or_whitespace(old_domain),
         false <- old_domain =~ @starts_with_https,
         false <- is_empty_or_whitespace(new_domain),
         false <- new_domain =~ @starts_with_https,
         old_domain_url <- "https://#{old_domain}",
         new_domain_url <- "https://#{new_domain}",
         {:ok, _} <- RoomObject.rewrite_domain_for_all(old_domain_url, new_domain_url),
         {:ok, _} <- Project.rewrite_domain_for_all(old_domain_url, new_domain_url),
         {:ok, _} <- Scene.rewrite_domain_for_all(old_domain_url, new_domain_url) do
      send_resp(conn, 200, %{success: true} |> Poison.encode!())
    else
      _err -> send_resp(conn, 500, %{error: :rewrite_assets_failed} |> Poison.encode!())
    end
  end

  defp is_empty_or_whitespace(str) do
    String.trim(str) === ""
  end
end
