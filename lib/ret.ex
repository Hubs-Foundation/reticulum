defmodule Ret do
  import Canada, only: [can?: 2]
  import Ecto.Query
  alias Ret.{Account, Avatar, AvatarListing, OwnedFile, Repo, Storage}

  def get_account_by_id(account_id) do
    Repo.get(Account, account_id)
  end

  def delete_account(%Account{} = acting_account, %Account{} = account_to_delete) do
    if can?(acting_account, delete_account(account_to_delete)) do
      reassign_avatar_listings(account_to_delete, acting_account)
      reassign_parent_avatars(account_to_delete, acting_account)
      delete_avatars_for_account(account_to_delete)

      case Repo.delete(account_to_delete) do
        {:ok, _} -> :ok
        {:error, _} -> {:error, :failed}
      end
    else
      {:error, :forbidden}
    end
  end

  defp delete_avatars_for_account(%Account{} = account) do
    account_avatars_query = from(avatar in Avatar, where: avatar.account_id == ^account.account_id)
    account_avatars = Repo.all(account_avatars_query) |> Repo.preload(Avatar.file_columns())

    account_avatar_owned_files =
      account_avatars
      |> Enum.flat_map(fn avatar ->
        Avatar.file_columns()
        |> Enum.map(fn column -> Map.fetch!(avatar, column) end)
        |> Enum.filter(fn owned_file -> owned_file != nil end)
      end)

    Repo.delete_all(account_avatars_query)
    delete_owned_files(account_avatar_owned_files)
  end

  defp delete_owned_files(owned_files) when is_list(owned_files) do
    for owned_file <- owned_files, do: OwnedFile.set_inactive(owned_file)
    for owned_file <- owned_files, do: Storage.rm_files_for_owned_file(owned_file)
    for owned_file <- owned_files, do: Repo.delete(owned_file)
  end

  defp reassign_avatar_listings(%Account{} = old_account, %Account{} = new_account) do
    reassign_owned_files_for_avatar_or_listing(AvatarListing, old_account, new_account)

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
    reassign_owned_files_for_avatar_or_listing(Avatar, old_account, new_account)

    Repo.update_all(
      from(a1 in Avatar,
        join: a2 in Avatar,
        on: a1.avatar_id == a2.parent_avatar_id,
        where: a1.account_id == ^old_account.account_id
      ),
      set: [account_id: new_account.account_id]
    )
  end

  defp reassign_owned_files_for_avatar_or_listing(schema, %Account{} = old_account, %Account{} = new_account)
       when schema in [Avatar, AvatarListing] do
    Repo.update_all(
      from(o in OwnedFile,
        join: avatar_or_lisiting in ^schema,
        on:
          o.owned_file_id == avatar_or_lisiting.gltf_owned_file_id or
            o.owned_file_id == avatar_or_lisiting.bin_owned_file_id or
            o.owned_file_id == avatar_or_lisiting.thumbnail_owned_file_id or
            o.owned_file_id == avatar_or_lisiting.base_map_owned_file_id or
            o.owned_file_id == avatar_or_lisiting.emissive_map_owned_file_id or
            o.owned_file_id == avatar_or_lisiting.normal_map_owned_file_id or
            o.owned_file_id == avatar_or_lisiting.orm_map_owned_file_id,
        where: avatar_or_lisiting.account_id == ^old_account.account_id
      ),
      set: [account_id: new_account.account_id]
    )
  end
end
