defmodule Ret.SceneTest do
  use Ret.DataCase, async: true

  alias Ret.{Account, OwnedFile, Repo, Scene, Storage}
  import Ret.TestHelpers, only: [create_account: 1, generate_temp_file: 1, generate_temp_owned_file: 1]

  @sample_domain "https://hubs.local"

  describe "rewrite_domain_for_all/2" do
    test "scene is rewritten" do
      old_domain_url = @sample_domain
      new_domain_url = dummy_domain_url()

      for _ <- 1..2 do
        dummy_account_prefix()
        |> create_account()
        |> create_scene_with_sample_owned_files()
      end

      Scene.rewrite_domain_for_all(old_domain_url, new_domain_url)

      for scene <- scenes(),
          owned_file <- [scene.model_owned_file, scene.scene_owned_file] do
        {:ok, _meta, stream} = Storage.fetch(owned_file)
        file_contents = Enum.join(stream)
        assert file_contents =~ new_domain_url
        refute file_contents =~ old_domain_url
      end
    end

    test "old assets are removed" do
      scene =
        dummy_account_prefix()
        |> create_account()
        |> create_scene_with_sample_owned_files()

      # We expect the scene we created above to have three owned files,
      # a model_owned_file, screenshot_owned_file, and scene_owned_file
      3 = Repo.aggregate(OwnedFile, :count)
      Repo.get!(OwnedFile, scene.scene_owned_file_id)
      Repo.get!(OwnedFile, scene.screenshot_owned_file_id)
      Repo.get!(OwnedFile, scene.model_owned_file_id)

      [_path, old_meta_file_path, old_blob_file_path] = Storage.paths_for_owned_file(scene.scene_owned_file)
      true = File.exists?(old_meta_file_path)
      true = File.exists?(old_blob_file_path)

      Scene.rewrite_domain_for_all(@sample_domain, dummy_domain_url())

      refute File.exists?(old_meta_file_path)
      refute File.exists?(old_blob_file_path)

      # The database should still only contain three owned files, since the old ones would have been deleted
      assert 3 === Repo.aggregate(OwnedFile, :count)
    end
  end

  @spec create_scene_with_sample_owned_files(Account.t()) :: Scene.t()
  defp create_scene_with_sample_owned_files(%Account{} = account) do
    model_owned_file = create_owned_file(account, File.read!("test/fixtures/test.glb"))
    screenshot_owned_file = generate_temp_owned_file(account)
    scene_owned_file = create_owned_file(account, @sample_domain)

    %Scene{}
    |> Scene.changeset(account, model_owned_file, screenshot_owned_file, scene_owned_file, %{name: dummy_scene_name()})
    |> Repo.insert!()
  end

  @spec create_owned_file(Account.t(), String.t()) :: OwnedFile.t()
  defp create_owned_file(%Account{} = account, file_contents) when is_binary(file_contents) do
    file_path = generate_temp_file(file_contents)
    {:ok, uuid} = Storage.store(%Plug.Upload{path: file_path}, "text/plain", "secret")
    {:ok, owned_file} = Storage.promote(uuid, "secret", nil, account)
    owned_file
  end

  @spec dummy_account_prefix :: String.t()
  defp dummy_account_prefix,
    do: "test-user-account-prefix-account-user"

  @spec dummy_domain_url :: String.t()
  defp dummy_domain_url,
    do: "http://example.com"

  @spec dummy_scene_name :: String.t()
  defp dummy_scene_name,
    do: "some name"

  @spec scenes :: [Scene.t()]
  defp scenes,
    do:
      Scene
      |> Repo.all()
      |> Repo.preload([:model_owned_file, :scene_owned_file])
end
