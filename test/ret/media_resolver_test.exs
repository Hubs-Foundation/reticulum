defmodule Ret.MediaResolverTest do
  use Ret.DataCase

  test "media resolver forbids requesting internal hosts" do
    :forbidden = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "http://127.0.0.1:3000/foo"})
    :forbidden = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "http://0.0.0.0"})
    :forbidden = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "https://192.168.0.1/foo"})
    :forbidden = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "http://127.0.0.1.sslip.io"})
  end

  test "media resolver errors when requesting non-existent hosts, or hosts without a public dns" do
    :error = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "http://hubs.local:3000/foo"})
    :error = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "http://localhost:4000/foo"})
    :error = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "https://missing.example.com/"})
  end

  test "media resolver succeeds when requesting public hosts" do
    {:commit, %Ret.ResolvedMedia{uri: %URI{host: "example.com"}}} =
      Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "https://example.com/"})
  end
end
