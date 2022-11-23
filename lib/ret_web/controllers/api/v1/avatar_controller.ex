defmodule RetWeb.Api.V1.AvatarController do
  use RetWeb, :controller

  alias Ret.{Account, Repo, Avatar, AvatarListing, Storage, GLTFUtils}

  plug(RetWeb.Plugs.RateLimit when action in [:create, :update])

  defp get_avatar(avatar_sid, preloads \\ []) do
    avatar_sid
    |> Avatar.avatar_or_avatar_listing_by_sid()
    |> preload(preloads)
  end

  defp preload(a) do
    preload(a, [])
  end

  defp preload(%Avatar{} = a, preloads) do
    a
    |> Repo.preload([
      Avatar.file_columns() ++
        [:parent_avatar, :parent_avatar_listing, :avatar_listings] ++ preloads
    ])
  end

  defp preload(%AvatarListing{} = a, preloads) do
    a |> Repo.preload([Avatar.file_columns() ++ [:avatar, :parent_avatar_listing] ++ preloads])
  end

  defp preload(_avatar, _preloads), do: nil

  def create(conn, %{"url" => url}) do
    try do
      account = Guardian.Plug.current_resource(conn)
      new_avatar = url |> URI.parse() |> Avatar.import_from_url!(account)
      conn |> render("create.json", avatar: new_avatar |> preload(), account: account)
    rescue
      _ -> render_error_json(conn, 400)
    end
  end

  def create(conn, %{"avatar" => %{"parent_avatar_listing_id" => parent_sid} = params}) do
    account = conn |> Guardian.Plug.current_resource()
    avatar = parent_sid |> Avatar.new_avatar_from_parent_sid(account)
    create_or_update(conn, params, avatar)
  end

  def update(conn, %{"id" => avatar_sid, "avatar" => params}) do
    case avatar_sid |> get_avatar() do
      %Avatar{} = avatar -> create_or_update(conn, params, avatar)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  defp create_or_update(conn, params, avatar) do
    account = conn |> Guardian.Plug.current_resource()
    create_or_update(conn, params, avatar, account)
  end

  defp create_or_update(
         conn,
         _params,
         %Avatar{account_id: avatar_account_id},
         %Account{account_id: account_id}
       )
       when not is_nil(avatar_account_id) and avatar_account_id != account_id do
    conn |> send_resp(401, "You do not own this avatar")
  end

  defp create_or_update(conn, params, avatar, account) do
    files_to_promote =
      (params["files"] || %{})
      |> Enum.map(fn
        {k, nil} -> {String.to_atom(k), :remove}
        {k, v} -> {String.to_atom(k), List.to_tuple(v)}
      end)
      |> Enum.into(%{})

    owned_file_results =
      files_to_promote
      |> Enum.map(fn
        {k, {id, key, promotion_token}} -> {k, Storage.promote(id, key, promotion_token, account)}
        {k, :remove} -> {k, {:ok, :remove}}
      end)
      |> Enum.into(%{})

    promotion_error =
      owned_file_results |> Map.values() |> Enum.filter(&(elem(&1, 0) == :error)) |> Enum.at(0)

    case promotion_error do
      nil ->
        owned_files =
          owned_file_results
          |> Enum.map(fn {k, {:ok, file}} -> {:"#{k}_owned_file", file} end)
          |> Enum.into(%{})

        parent_avatar =
          params["parent_avatar_id"] &&
            Repo.get_by(Avatar, avatar_sid: params["parent_avatar_id"])

        parent_avatar_listing =
          params["parent_avatar_listing_id"] &&
            Repo.get_by(AvatarListing, avatar_listing_sid: params["parent_avatar_listing_id"])

        {result, avatar} =
          avatar
          |> Avatar.changeset(account, owned_files, parent_avatar, parent_avatar_listing, params)
          |> Repo.insert_or_update()

        avatar = avatar |> preload()

        case result do
          :ok ->
            conn |> render("create.json", avatar: avatar, account: account)

          :error ->
            conn |> send_resp(422, "invalid avatar")
        end

      {:error, :not_found} ->
        conn |> send_resp(404, "no such file(s)")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "not allowed to promote file(s)")
    end
  end

  def show(conn, %{"id" => avatar_sid}) do
    conn |> show(avatar_sid |> get_avatar())
  end

  def show(conn, nil = _avatar) do
    conn |> send_resp(404, "")
  end

  def show(conn, %Avatar{state: :removed}), do: conn |> send_resp(404, "Avatar not found")
  def show(conn, %AvatarListing{state: :removed}), do: conn |> send_resp(404, "Avatar not found")

  def show(conn, %t{} = avatar) when t in [Avatar, AvatarListing] do
    account = conn |> Guardian.Plug.current_resource()
    conn |> render("show.json", avatar: avatar, account: account)
  end

  def show_avatar_gltf(conn, %{"id" => avatar_sid}) do
    conn |> show_gltf(avatar_sid |> get_avatar(), true)
  end

  def show_base_gltf(conn, %{"id" => avatar_sid}) do
    case avatar_sid |> get_avatar([:parent_avatar_listing]) do
      # For avatars with a parent, base is the same as the parents collapsed avatar plus gltf override
      %{parent_avatar_listing: parent_listing} = avatar when not is_nil(parent_listing) ->
        case avatar.gltf_owned_file do
          nil ->
            conn |> show_gltf(parent_listing |> preload, true)

          gltf ->
            conn |> show_gltf(parent_listing |> preload |> Map.put(:gltf_owned_file, gltf), true)
        end

      # Otherwise base is just not applying overrides the the avatar
      avatar ->
        conn |> show_gltf(avatar, false)
    end
  end

  def show_gltf(conn, nil = _avatar, _apply_overrides) do
    conn |> send_resp(404, "Avatar not found")
  end

  def show_gltf(conn, %Avatar{state: :removed}, _overrides),
    do: conn |> send_resp(404, "Avatar not found")

  def show_gltf(conn, %AvatarListing{state: :removed}, _overrides),
    do: conn |> send_resp(404, "Avatar not found")

  def show_gltf(conn, %t{} = a, apply_overrides) when t in [Avatar, AvatarListing],
    do: conn |> show_gltf(a |> Avatar.collapsed_files(), apply_overrides)

  def show_gltf(conn, avatar_files, apply_overrides) do
    case Storage.fetch(avatar_files.gltf_owned_file) do
      {:ok, _meta, stream} ->
        gltf =
          stream
          |> Enum.join("")
          |> Poison.decode!()
          |> GLTFUtils.with_default_material_override(
            (apply_overrides && avatar_files |> Map.take(Avatar.image_columns())) || []
          )
          |> GLTFUtils.with_buffer_override(avatar_files.bin_owned_file)

        conn
        # |> put_resp_content_type("model/gltf", nil)
        |> send_resp(200, gltf |> Poison.encode!())

      {:error, :not_found} ->
        conn |> send_resp(404, "Avatar is missing a gltf file")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "You are not allowed to access this avatar")
    end
  end

  def delete(conn, %{"id" => avatar_sid}) do
    account = Guardian.Plug.current_resource(conn)

    case avatar_sid |> get_avatar() do
      %Avatar{} = avatar -> delete(conn, avatar, account)
      _ -> conn |> send_resp(404, "not found")
    end
  end

  def delete(conn, _avatar), do: conn |> send_resp(401, "You do not own this avatar")

  def delete(conn, %Avatar{account_id: avatar_account_id} = avatar, %Account{
        account_id: account_id
      })
      when not is_nil(avatar_account_id) and avatar_account_id == account_id do
    avatar
    |> Avatar.delete_avatar_and_delist_listings()
    |> case do
      {:ok, _} -> send_resp(conn, 200, "OK")
      {:error, error} -> render_error_json(conn, error)
    end
  end
end
