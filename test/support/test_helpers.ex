defmodule Ret.TestHelpers do
  alias Ret.{
    Account,
    Asset,
    Avatar,
    AvatarListing,
    Hub,
    Project,
    ProjectAsset,
    Repo,
    Scene,
    SceneListing,
    Storage
  }

  def generate_temp_owned_file(account) do
    temp_file = generate_temp_file("test")
    {:ok, uuid} = Storage.store(%Plug.Upload{path: temp_file}, "text/plain", "secret")
    {:ok, owned_file} = Storage.promote(uuid, "secret", nil, account)
    owned_file
  end

  def generate_fixture_owned_file(account, path, content_type) do
    {:ok, uuid} = Storage.store(%Plug.Upload{path: path}, content_type, "secret")
    {:ok, owned_file} = Storage.promote(uuid, "secret", nil, account)
    owned_file
  end

  def generate_temp_file(contents) do
    {:ok, temp_path} = Temp.mkdir("stored-file-test")
    file_path = temp_path |> Path.join("test.txt")
    file_path |> File.write(contents)
    file_path
  end

  def auth_with_account(conn, account) do
    {:ok, token, _claims} = account |> Ret.Guardian.encode_and_sign()
    put_auth_header_for_token(conn, token)
  end

  def put_auth_header_for_token(conn, token) do
    conn |> Plug.Conn.put_req_header("authorization", "bearer: " <> token)
  end

  def create_random_account(), do: create_account(Ret.Sids.generate_sid())

  def create_account(prefix, is_admin \\ false)

  def create_account(prefix, is_admin) when is_binary(prefix) do
    account = Account.find_or_create_account_for_email("#{prefix}@mozilla.com")

    if is_admin do
      # Currently admin bits not set via any reticulum APIs, so avoid adding them to code for now.
      Ecto.Adapters.SQL.query!(
        Ret.Repo,
        "update ret0.accounts set is_admin = 't' where account_id = #{account.account_id}"
      )

      Account.find_or_create_account_for_email("#{prefix}@mozilla.com")
    else
      account
    end
  end

  def create_account(_, _is_admin) do
    {:ok, account: create_account("test"), account2: create_account("test2")}
  end

  def create_admin_account(prefix) do
    {:ok, admin_account: create_account(prefix, true)}
  end

  def create_owned_file(%{account: account}) do
    {:ok, owned_file: generate_temp_owned_file(account)}
  end

  @spec create_owned_file(Account.t(), String.t()) :: OwnedFile.t()
  def create_owned_file(%Account{} = account, file_contents) when is_binary(file_contents) do
    file_path = generate_temp_file(file_contents)
    {:ok, uuid} = Storage.store(%Plug.Upload{path: file_path}, "text/plain", "secret")
    {:ok, owned_file} = Storage.promote(uuid, "secret", nil, account)
    owned_file
  end

  def create_scene(%Account{} = account) do
    {:ok, scene: scene} =
      create_scene(%{account: account, owned_file: generate_temp_owned_file(account)})

    scene
  end

  def create_scene(%{account: account, owned_file: owned_file}) do
    {:ok, scene} =
      %Scene{}
      |> Scene.changeset(account, owned_file, owned_file, owned_file, %{
        name: "Test Scene",
        description: "Test Scene Description",
        allow_promotion: true
      })
      |> Repo.insert_or_update()

    scene =
      scene
      |> Repo.preload([:model_owned_file, :screenshot_owned_file, :scene_owned_file, :account])

    {:ok, scene: scene}
  end

  def create_avatar(%{account: account}) do
    {:ok, avatar: create_avatar(account)}
  end

  def create_avatar(account) do
    {:ok, avatar} =
      %Avatar{}
      |> Avatar.changeset(
        account,
        %{
          gltf_owned_file: generate_temp_owned_file(account),
          bin_owned_file: generate_temp_owned_file(account)
        },
        nil,
        nil,
        %{
          name: "Test Avatar"
        }
      )
      |> Repo.insert_or_update()

    avatar
  end

  def create_avatar_listing(%{avatar: avatar}) do
    {:ok, avatar_listing: create_avatar_listing(avatar)}
  end

  def create_avatar_listing(avatar) do
    {:ok, listing} =
      %AvatarListing{}
      |> AvatarListing.changeset_for_listing_for_avatar(avatar, %{})
      |> Repo.insert()

    listing
  end

  def create_scene_listing(%{scene: scene}) do
    {:ok, listing} =
      %SceneListing{}
      |> SceneListing.changeset_for_listing_for_scene(
        scene,
        %{tags: %{tags: ["foo", "bar", "biz"]}}
      )
      |> Repo.insert()

    {:ok, scene_listing: listing}
  end

  def create_hub(%{scene: scene}) do
    {:ok, hub} = %Hub{} |> Hub.changeset(scene, %{name: "Test Hub"}) |> Repo.insert()

    {:ok, hub: hub}
  end

  def create_public_hub(%{scene: scene}) do
    {:ok, hub} =
      %Hub{}
      |> Hub.changeset(scene, %{name: "Test Public Hub"})
      |> Hub.add_promotion_to_changeset(%{"allow_promotion" => true})
      |> Repo.insert()

    {:ok, hub: hub}
  end

  def create_project_owned_file(%{account: account}) do
    project_file = Path.expand("../fixtures/spoke-project.json", __DIR__)

    {:ok,
     project_owned_file: generate_fixture_owned_file(account, project_file, "application/json")}
  end

  def create_thumbnail_owned_file(%{account: account}) do
    thumbnail_file = Path.expand("../fixtures/spoke-thumbnail.jpg", __DIR__)
    {:ok, thumbnail_owned_file: generate_fixture_owned_file(account, thumbnail_file, "image/png")}
  end

  def create_model_owned_file(%{account: account}) do
    {:ok, model_owned_file: generate_temp_owned_file(account)}
  end

  def create_project(%{
        account: account,
        project_owned_file: project_owned_file,
        thumbnail_owned_file: thumbnail_owned_file
      }) do
    {:ok, project} =
      %Project{}
      |> Project.changeset(account, project_owned_file, thumbnail_owned_file, %{
        name: "Test Project"
      })
      |> Repo.insert_or_update()

    project =
      project |> Repo.preload([:project_owned_file, :thumbnail_owned_file, :created_by_account])

    {:ok, project: project}
  end

  def create_asset(%{account: account, thumbnail_owned_file: owned_file}) do
    {:ok, asset} =
      %Asset{}
      |> Asset.changeset(account, owned_file, owned_file, %{
        name: "Test Asset"
      })
      |> Repo.insert_or_update()

    {:ok, asset: asset}
  end

  def create_project_asset(%{account: account, project: project, thumbnail_owned_file: owned_file}) do
    {:ok, asset} =
      %Asset{}
      |> Asset.changeset(account, owned_file, owned_file, %{
        name: "Test Project Asset"
      })
      |> Repo.insert_or_update()

    {:ok, project_asset} =
      %ProjectAsset{}
      |> ProjectAsset.changeset(project, asset)
      |> Repo.insert_or_update()

    project_asset = project_asset |> Repo.preload([:project, :asset])
    {:ok, project_asset: project_asset}
  end

  def clear_all_stored_files do
    File.rm_rf(Application.get_env(:ret, Storage)[:storage_path])
  end

  def put_auth_header_for_email(conn, email) do
    put_auth_header_for_account(conn, Ret.Account.find_or_create_account_for_email(email))
  end

  def put_auth_header_for_account(conn, account) do
    {:ok, token, _claims} = Ret.Guardian.encode_and_sign(account)

    conn |> Plug.Conn.put_req_header("authorization", "bearer: " <> token)
  end

  def assign_creator(hub, account) do
    hub
    |> Ret.Repo.preload(created_by_account: [])
    |> Ret.Hub.changeset_for_creator_assignment(account, hub.creator_assignment_token)
    |> Ret.Repo.update!()
  end

  def merge_module_config(app, key, configs) do
    current_config = Application.get_env(app, key, %{})
    Application.put_env(app, key, Map.merge(current_config, configs))
  end
end
