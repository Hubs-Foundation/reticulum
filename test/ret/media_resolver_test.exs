defmodule Ret.MediaResolverTest do
  use Ret.DataCase

  test "media resolver errors when requesting internal hosts" do
    :error = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "http://127.0.0.1:3000/foo"})
    :error = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "http://0.0.0.0"})
    :error = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "http://localhost:4000/foo"})
    :error = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "https://192.168.0.1/foo"})
    :error = Ret.MediaResolver.resolve(%Ret.MediaResolverQuery{url: "http://127.0.0.1.sslip.io"})
  end
end
