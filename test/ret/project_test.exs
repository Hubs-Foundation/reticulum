defmodule Ret.ProjectTest do
  use Ret.DataCase, async: true

  alias Ret.{Account, DummyData, OwnedFile, Repo, Project, Storage}

  import Ret.TestHelpers,
    only: [create_account: 1, create_owned_file: 2, generate_temp_owned_file: 1]

  @sample_domain "https://hubs.local"

  describe "rewrite_domain_for_all/2" do
    test "project is rewritten" do
      old_domain_url = @sample_domain
      new_domain_url = DummyData.domain_url()

      for _ <- 1..2 do
        DummyData.account_prefix()
        |> create_account()
        |> create_project_with_sample_owned_files()
      end

      Project.rewrite_domain_for_all(old_domain_url, new_domain_url)

      for project <- projects() do
        {:ok, _meta, stream} = Storage.fetch(project.project_owned_file)
        file_contents = Enum.join(stream)
        assert file_contents =~ new_domain_url
        refute file_contents =~ old_domain_url
      end
    end

    test "old assets are removed" do
      project =
        DummyData.account_prefix()
        |> create_account()
        |> create_project_with_sample_owned_files()

      # We expect the project we created above to have two owned files,
      # a project_owned_file and thumbnail_owned_file.
      2 = Repo.aggregate(OwnedFile, :count)
      Repo.get!(OwnedFile, project.project_owned_file_id)
      Repo.get!(OwnedFile, project.thumbnail_owned_file_id)

      [_path, old_meta_file_path, old_blob_file_path] =
        Storage.paths_for_owned_file(project.project_owned_file)

      true = File.exists?(old_meta_file_path)
      true = File.exists?(old_blob_file_path)

      Project.rewrite_domain_for_all(@sample_domain, DummyData.domain_url())

      refute File.exists?(old_meta_file_path)
      refute File.exists?(old_blob_file_path)

      assert 2 === Repo.aggregate(OwnedFile, :count)
    end
  end

  @spec create_project_with_sample_owned_files(Account.t()) :: Project.t()
  defp create_project_with_sample_owned_files(%Account{} = account) do
    project_owned_file = create_owned_file(account, @sample_domain)
    thumbnail_owned_file = generate_temp_owned_file(account)

    %Project{}
    |> Project.changeset(account, project_owned_file, thumbnail_owned_file, %{
      name: DummyData.project_name()
    })
    |> Repo.insert!()
    |> Repo.preload([:project_owned_file])
  end

  @spec projects :: [Project.t()]
  defp projects,
    do:
      Project
      |> Repo.all()
      |> Repo.preload([:project_owned_file])
end
