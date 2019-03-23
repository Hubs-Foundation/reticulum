defmodule Ret.CachedFileTest do
  use Ret.DataCase
  import Ret.TestHelpers

  alias Ret.{CachedFile, Storage}

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  test "cache a file" do
    uri_cold =
      CachedFile.fetch("foo", fn path ->
        File.write(path, "test")
        {:ok, %{content_type: "application/json"}}
      end)

    uri_hot =
      CachedFile.fetch("foo", fn path ->
        File.write(path, "test2")
        {:ok, %{content_type: "application/json"}}
      end)

    assert uri_hot != nil
    assert uri_hot == uri_cold
  end

  test "vaccuum shouldn't fail" do
    CachedFile.vacuum()
  end
end
