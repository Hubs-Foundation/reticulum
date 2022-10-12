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

  test "Requests to internal ips are forbidden", %{conn: conn} do
    resp = conn |> post("/api/v1/media", %{media: %{url: "https://127.0.0.1:8080"}})
    assert resp.status === 403
  end

  test "Requests to non-existent hosts result in an error", %{conn: conn} do
    resp = conn |> post("/api/v1/media", %{media: %{url: "https://missing.example.com"}})
    assert resp.status === 500
  end

  test "Requests to local hosts result in an error", %{conn: conn} do
    resp = conn |> post("/api/v1/media", %{media: %{url: "https://localhost"}})
    assert resp.status === 500
  end
end
