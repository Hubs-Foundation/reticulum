defmodule RetWeb.MediaControllerTest do
  use RetWeb.ConnCase
  import Ret.TestHelpers

  test "HTML uploads are rejected", %{conn: conn} do
    temp_file = generate_temp_file("<h1>test</h1>")
    params = %{
      media: %Plug.Upload{path: temp_file, filename: "test.html", content_type: "text/html"},
      desired_content_type: "text/html"
    }
    resp = conn |> post("/api/v1/media", params)
    assert resp.status === 403
  end

  test "JavaScript uploads are rejected", %{conn: conn} do
    temp_file = generate_temp_file("alert('hi');")
    params = %{
      media: %Plug.Upload{path: temp_file, filename: "test.js", content_type: "text/javascript"},
      desired_content_type: "text/javascript"
    }
    resp = conn |> post("/api/v1/media", params)
    assert resp.status === 403
  end
end
