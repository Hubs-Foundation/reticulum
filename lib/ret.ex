defmodule Ret do
  import Canada, only: [can?: 2]
  import Ecto.Query
  alias Ret.{Account, Asset, Avatar, AvatarListing, OwnedFile, Project, Repo, Scene, SceneListing, Storage}

  def get_account_by_id(account_id) do
    Repo.get(Account, account_id)
  end

  @asset_file_columns [:asset_owned_file, :thumbnail_owned_file]
  @project_file_columns [:project_owned_file, :thumbnail_owned_file]
  @scene_file_columns [:scene_owned_file, :screenshot_owned_file, :model_owned_file]
  def delete_account(%Account{} = acting_account, %Account{} = account_to_delete) do
    if can?(acting_account, delete_account(account_to_delete)) do
      reassign_avatar_listings(account_to_delete, acting_account)
      reassign_parent_avatars(account_to_delete, acting_account)
      reassign_scene_listings(account_to_delete, acting_account)

      delete_entities_with_owned_files(
        from(avatar in Avatar, where: avatar.account_id == ^account_to_delete.account_id),
        Avatar.file_columns()
      )

      delete_entities_with_owned_files(
        from(asset in Asset, where: asset.account_id == ^account_to_delete.account_id),
        @asset_file_columns
      )

      delete_entities_with_owned_files(
        from(project in Project, where: project.created_by_account_id == ^account_to_delete.account_id),
        @project_file_columns
      )

      delete_entities_with_owned_files(
        from(scene in Scene, where: scene.account_id == ^account_to_delete.account_id),
        @scene_file_columns
      )

      case Repo.delete(account_to_delete) do
        {:ok, _} -> :ok
        {:error, _} -> {:error, :failed}
      end
    else
      {:error, :forbidden}
    end
  end

  defp delete_entities_with_owned_files(query, file_columns) when is_list(file_columns) do
    entities = Repo.all(query) |> Repo.preload(file_columns)
    entity_owned_files = Enum.flat_map(entities, fn entity -> entity_owned_files(entity, file_columns) end)
    Repo.delete_all(query)
    delete_owned_files(entity_owned_files)
  end

  defp entity_owned_files(entity, file_columns) do
    for column <- file_columns,
        owned_file = Map.fetch!(entity, column),
        do: owned_file
  end

  defp delete_owned_files(owned_files) when is_list(owned_files) do
    for owned_file <- owned_files do
      OwnedFile.set_inactive(owned_file)
      Storage.rm_files_for_owned_file(owned_file)
      Repo.delete(owned_file)
    end
  end

  defp reassign_avatar_listings(%Account{} = old_account, %Account{} = new_account) do
    reassign_owned_files_for_avatars_or_listings(AvatarListing, old_account, new_account)

    Repo.update_all(
      from(av in Avatar,
        join: al in AvatarListing,
        on: av.avatar_id == al.avatar_id,
        where: av.account_id == ^old_account.account_id
      ),
      set: [account_id: new_account.account_id]
    )

    Repo.update_all(
      from(al in AvatarListing, where: al.account_id == ^old_account.account_id),
      set: [account_id: new_account.account_id]
    )
  end

  defp reassign_parent_avatars(%Account{} = old_account, %Account{} = new_account) do
    reassign_owned_files_for_avatars_or_listings(Avatar, old_account, new_account)

    Repo.update_all(
      from(a1 in Avatar,
        join: a2 in Avatar,
        on: a1.avatar_id == a2.parent_avatar_id,
        where: a1.account_id == ^old_account.account_id
      ),
      set: [account_id: new_account.account_id]
    )
  end

  defp reassign_owned_files_for_avatars_or_listings(schema, %Account{} = old_account, %Account{} = new_account)
       when schema in [Avatar, AvatarListing] do
    Repo.update_all(
      from(o in OwnedFile,
        join: avatar_or_listing in ^schema,
        on:
          o.owned_file_id == avatar_or_listing.gltf_owned_file_id or
            o.owned_file_id == avatar_or_listing.bin_owned_file_id or
            o.owned_file_id == avatar_or_listing.thumbnail_owned_file_id or
            o.owned_file_id == avatar_or_listing.base_map_owned_file_id or
            o.owned_file_id == avatar_or_listing.emissive_map_owned_file_id or
            o.owned_file_id == avatar_or_listing.normal_map_owned_file_id or
            o.owned_file_id == avatar_or_listing.orm_map_owned_file_id,
        where: avatar_or_listing.account_id == ^old_account.account_id
      ),
      set: [account_id: new_account.account_id]
    )
  end

  defp reassign_scene_listings(%Account{} = old_account, %Account{} = new_account) do
    reassign_owned_files_for_scene_listings(old_account, new_account)

    Repo.update_all(
      from(sc in Scene,
        join: sl in SceneListing,
        on: sc.scene_id == sl.scene_id,
        where: sc.account_id == ^old_account.account_id
      ),
      set: [account_id: new_account.account_id]
    )
  end

  defp reassign_owned_files_for_scene_listings(%Account{} = old_account, %Account{} = new_account) do
    Repo.update_all(
      from(o in OwnedFile,
        join: sl in SceneListing,
        join: sc in Scene,
        on:
          (o.owned_file_id == sl.model_owned_file_id or
             o.owned_file_id == sl.screenshot_owned_file_id or
             o.owned_file_id == sl.scene_owned_file_id) and
            sl.scene_id == sc.scene_id,
        where: sc.account_id == ^old_account.account_id
      ),
      set: [account_id: new_account.account_id]
    )
  end
end
