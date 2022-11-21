defmodule Ret do
  @moduledoc """
  The boundary of the Ret context.
  """
  alias Ret.{Account, Asset, Avatar, AvatarListing, Login, OwnedFile, Project, Repo, Scene, SceneListing, Storage}
  import Canada, only: [can?: 2]
  import Ret.Schema, only: [is_serial_id: 1]
  require Ecto.Query

  def change_email_for_login(%{old_email: old_email, new_email: new_email}) do
    if not valid_email_address?(new_email) do
      {:error, :invalid_parameters}
    else
      change_email_for_login(
        Repo.get_by(Login, identifier_hash: Account.identifier_hash_for_email(old_email)),
        new_email
      )
    end
  end

  defp change_email_for_login(nil, _new_email) do
    {:error, :no_account_for_old_email}
  end

  defp change_email_for_login(%Login{} = login, new_email) do
    login
    |> Ecto.Changeset.change(identifier_hash: Account.identifier_hash_for_email(new_email))
    |> Ecto.Changeset.unique_constraint(:identifier_hash)
    |> Repo.update()
    |> case do
      {:error, %Ecto.Changeset{errors: [identifier_hash: {_, [{:constraint, :unique}, _]}]}} ->
        {:error, :new_email_already_in_use}

      {:ok, _} ->
        :ok
    end
  end

  defp valid_email_address?(string) do
    string =~ ~r/\S+@\S+/
  end

  @doc """
  Obliterates the account with the given `account_id` and all its owned assets.

  Returns `:ok` if successful, otherwise it returns `{:error, reason}`.

  Error reasons are:

  * `:forbidden` - the current user does not have sufficient authorization or
    an account could not be found with the given `account_id`
  * `:failed` - the account data was unable to be deleted for an unknown reason

  """
  @spec delete_account(Account.id(), Account.t()) :: :ok | {:error, :forbidden | :failed}
  def delete_account(account_id, %Account{} = current_user) when is_serial_id(account_id) do
    account_to_delete = Repo.get(Account, account_id)

    cond do
      !account_to_delete ->
        {:error, :forbidden}

      not can?(current_user, delete_account(account_to_delete)) ->
        {:error, :forbidden}

      true ->
        reassignment = [set: [account_id: current_user.account_id]]

        Ecto.Multi.new()
        |> Ecto.Multi.delete_all(:delete_assets, asset_query(account_id))
        |> Ecto.Multi.delete_all(:delete_projects, project_query(account_id))
        |> delete_avatars_multi(account_id, reassignment)
        |> delete_scenes_multi(account_id, reassignment)
        |> delete_owned_files_multi(account_id)
        |> Ecto.Multi.delete(:delete_account, account_to_delete)
        |> Repo.transaction()
        |> case do
          {:ok, _} ->
            :ok

          {:error, _} ->
            {:error, :failed}
        end
    end
  end

  @spec account_owned_file_query(Account.id()) :: Ecto.Query.t()
  defp account_owned_file_query(account_id) when is_serial_id(account_id),
    do: Ecto.Query.where(OwnedFile, account_id: ^account_id)

  @spec asset_query(Account.id()) :: Ecto.Query.t()
  defp asset_query(account_id) when is_serial_id(account_id),
    do: Ecto.Query.where(Asset, account_id: ^account_id)

  @spec avatar_owned_file_query(Account.id()) :: Ecto.Query.t()
  defp avatar_owned_file_query(account_id) when is_serial_id(account_id),
    do:
      Ecto.Query.from(owned_file in OwnedFile,
        join: avatar in Avatar,
        on:
          owned_file.owned_file_id == avatar.gltf_owned_file_id or
            owned_file.owned_file_id == avatar.bin_owned_file_id or
            owned_file.owned_file_id == avatar.thumbnail_owned_file_id or
            owned_file.owned_file_id == avatar.base_map_owned_file_id or
            owned_file.owned_file_id == avatar.emissive_map_owned_file_id or
            owned_file.owned_file_id == avatar.normal_map_owned_file_id or
            owned_file.owned_file_id == avatar.orm_map_owned_file_id,
        where: avatar.account_id == ^account_id
      )

  @spec avatar_query(Account.id()) :: Ecto.Query.t()
  defp avatar_query(account_id) when is_serial_id(account_id),
    do: Ecto.Query.where(Avatar, account_id: ^account_id)

  @spec delete_avatars_multi(Ecto.Multi.t(), Account.id(), Keyword.t()) :: Ecto.Multi.t()
  defp delete_avatars_multi(%Ecto.Multi{} = multi, account_id, reassignment)
       when is_serial_id(account_id) and is_list(reassignment),
       do:
         multi
         |> Ecto.Multi.update_all(:reassign_avatar_owned_files, avatar_owned_file_query(account_id), reassignment)
         |> Ecto.Multi.update_all(:reassign_listed_avatars, listed_avatar_query(account_id), reassignment)
         |> Ecto.Multi.update_all(:reassign_parent_avatars, parent_avatar_query(account_id), reassignment)
         |> ecto_multi_all(:avatar_owned_files, avatar_owned_file_query(account_id))
         |> Ecto.Multi.delete_all(:delete_avatars, avatar_query(account_id))
         |> Ecto.Multi.run(:delete_avatar_owned_files, &delete_owned_files(&2.avatar_owned_files, &1))

  @spec delete_owned_files([OwnedFile.t()], module) :: {:ok, nil} | {:error, Ecto.Changeset.t(OwnedFile.t())}
  defp delete_owned_files(owned_files, repo) when is_list(owned_files) and is_atom(repo) do
    Enum.reduce_while(owned_files, {:ok, nil}, fn owned_file, acc ->
      with {:ok, _} <- OwnedFile.set_inactive(owned_file),
           Storage.rm_files_for_owned_file(owned_file),
           {:ok, _} <- repo.delete(owned_file) do
        {:cont, acc}
      else
        error ->
          {:halt, error}
      end
    end)
  end

  @spec delete_owned_files_multi(Ecto.Multi.t(), Account.id()) :: Ecto.Multi.t()
  defp delete_owned_files_multi(%Ecto.Multi{} = multi, account_id) when is_serial_id(account_id),
    do:
      multi
      |> ecto_multi_all(:account_owned_files, account_owned_file_query(account_id))
      |> Ecto.Multi.run(:delete_account_owned_files, &delete_owned_files(&2.account_owned_files, &1))

  @spec delete_scenes_multi(Ecto.Multi.t(), Account.id(), Keyword.t()) :: Ecto.Multi.t()
  defp delete_scenes_multi(%Ecto.Multi{} = multi, account_id, reassignment)
       when is_serial_id(account_id) and is_list(reassignment),
       do:
         multi
         |> Ecto.Multi.update_all(:reassign_scene_owned_files, scene_owned_file_query(account_id), reassignment)
         |> Ecto.Multi.update_all(:reassign_listed_scenes, listed_scene_query(account_id), reassignment)
         |> Ecto.Multi.update_all(:reassign_parent_scenes, parent_scene_query(account_id), reassignment)
         |> ecto_multi_all(:scene_owned_files, scene_owned_file_query(account_id))
         |> Ecto.Multi.delete_all(:delete_scenes, scene_query(account_id))
         |> Ecto.Multi.run(:delete_scene_owned_files, &delete_owned_files(&2.scene_owned_files, &1))

  # TODO: Replace calls with Ecto.Multi.all/3 after Ecto updgrade
  @spec ecto_multi_all(Ecto.Multi.t(), atom, Ecto.Query.t()) :: Ecto.Multi.t()
  defp ecto_multi_all(%Ecto.Multi{} = multi, name, %Ecto.Query{} = query) when is_atom(name) do
    Ecto.Multi.run(multi, name, fn repo, _changes ->
      {:ok, repo.all(query)}
    end)
  end

  @spec listed_avatar_query(Account.id()) :: Ecto.Query.t()
  defp listed_avatar_query(account_id) when is_serial_id(account_id),
    do:
      Ecto.Query.from(avatar in Avatar,
        join: listing in AvatarListing,
        on: avatar.avatar_id == listing.avatar_id,
        where: avatar.account_id == ^account_id
      )

  @spec listed_scene_query(Account.id()) :: Ecto.Query.t()
  defp listed_scene_query(account_id) when is_serial_id(account_id),
    do:
      Ecto.Query.from(scene in Scene,
        join: listing in SceneListing,
        on: scene.scene_id == listing.scene_id,
        where: scene.account_id == ^account_id
      )

  @spec parent_avatar_query(Account.id()) :: Ecto.Query.t()
  defp parent_avatar_query(account_id) when is_serial_id(account_id),
    do:
      Ecto.Query.from(parent_avatar in Avatar,
        join: child_avatar in Avatar,
        on: parent_avatar.avatar_id == child_avatar.parent_avatar_id,
        where: parent_avatar.account_id == ^account_id
      )

  @spec parent_scene_query(Account.id()) :: Ecto.Query.t()
  defp parent_scene_query(account_id) when is_serial_id(account_id),
    do:
      Ecto.Query.from(parent_scene in Scene,
        join: child_scene in Scene,
        on: parent_scene.scene_id == child_scene.parent_scene_id,
        where: parent_scene.account_id == ^account_id
      )

  @spec project_query(Account.id()) :: Ecto.Query.t()
  defp project_query(account_id) when is_serial_id(account_id),
    do: Ecto.Query.where(Project, created_by_account_id: ^account_id)

  @spec scene_owned_file_query(Account.id()) :: Ecto.Query.t()
  defp scene_owned_file_query(account_id) when is_serial_id(account_id),
    do:
      Ecto.Query.from(owned_file in OwnedFile,
        join: scene in Scene,
        on:
          owned_file.owned_file_id == scene.model_owned_file_id or
            owned_file.owned_file_id == scene.screenshot_owned_file_id or
            owned_file.owned_file_id == scene.scene_owned_file_id,
        where: scene.account_id == ^account_id
      )

  @spec scene_query(Account.id()) :: Ecto.Query.t()
  defp scene_query(account_id) when is_serial_id(account_id),
    do: Ecto.Query.where(Scene, account_id: ^account_id)
end
