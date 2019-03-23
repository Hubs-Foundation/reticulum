defmodule Ret.CachedFileTest do
  use Ret.DataCase
  import Ret.TestHelpers

  alias Ret.{CachedFile, Storage}

  setup do
    on_exit(fn ->
      clear_all_stored_files()
    end)
  end

  setup _context do
    %{temp_file: generate_temp_file("test"), temp_file_2: generate_temp_file("test2")}
  end

  test "cache a file", %{temp_file: temp_file} do
    uri_cold =
      CachedFile.fetch("foo", fn ->
        %{path: temp_file, content_type: "application/json"}
      end)

    uri_hot =
      CachedFile.fetch("foo", fn ->
        %{path: temp_file, content_type: "application/json"}
      end)

    assert uri_hot != nil
    assert uri_hot == uri_cold
  end

  test "vaccuum shouldn't fail" do
    CachedFile.vacuum()
  end
end
