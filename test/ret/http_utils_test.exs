defmodule Ret.HttpUtilsTest do
  use ExUnit.Case

  setup_all do
    Mox.defmock(Ret.HttpMock, for: HTTPoison.Base)
    Ret.TestHelpers.merge_module_config(:ret, Ret.HttpUtils, %{:http_client => Ret.HttpMock})

    on_exit(fn ->
      Ret.TestHelpers.merge_module_config(:ret, Ret.HttpUtils, %{:http_client => nil})
    end)
  end

  test "fetch_content_type should attempt a request and return the response content type" do
    Ret.HttpMock
    |> Mox.expect(:request, 1, fn _verb, _url, _body, _headers, _options ->
      {:ok, %HTTPoison.Response{status_code: 200, headers: %{"content-type" => "foo/bar"}}}
    end)

    {:ok, "foo/bar"} = Ret.HttpUtils.fetch_content_type("http://foo.local/")
  end
end
