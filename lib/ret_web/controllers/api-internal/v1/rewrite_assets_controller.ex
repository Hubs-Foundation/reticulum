defmodule RetWeb.ApiInternal.V1.RewriteAssetsController do
  use RetWeb, :controller

  alias Ret.{RoomObject, Project, Scene}

  def post(conn, %{"old_domain" => old_domain, "new_domain" => new_domain})
      when is_binary(old_domain) and is_binary(new_domain) and old_domain != "" and new_domain != "" do
    conn = put_resp_header(conn, "content-type", "application/json")

    old_domain_url = "https://#{old_domain}"
    new_domain_url = "https://#{new_domain}"

    # TODO HACK We're retrieving and manipulating a lot of records and files here, which is pretty ineffiecient.
    # We should instead try to avoid baking the domain into these assets in the first place.

    with {:ok, _} <- RoomObject.rewrite_domain_for_all(old_domain_url, new_domain_url),
         {:ok, _} <- Project.rewrite_domain_for_all(old_domain_url, new_domain_url),
         {:ok, _} <- Scene.rewrite_domain_for_all(old_domain_url, new_domain_url) do
      send_resp(conn, 200, %{success: true} |> Poison.encode!())
    else
      _err -> send_resp(conn, 500, %{error: :rewrite_assets_failed} |> Poison.encode!())
    end
  end
end
