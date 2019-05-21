defmodule RetWeb.Api.V1.AvatarController do
  use RetWeb, :controller

  alias Ret.{Account, Repo, Avatar, AvatarListing, Storage, GLTFUtils}

  plug(RetWeb.Plugs.RateLimit when action in [:create, :update])

  @primary_material_name "Bot_PBS"

  defp get_avatar(avatar_sid) do
    avatar_sid
    |> Avatar.avatar_or_avatar_listing_by_sid()
    |> preload()
  end

  defp preload(%Avatar{} = a) do
    a |> Repo.preload([Avatar.file_columns() ++ [:parent_avatar, :parent_avatar_listing, :account]])
  end

  defp preload(%AvatarListing{} = a) do
    a |> Repo.preload([Avatar.file_columns() ++ [:avatar, :parent_avatar_listing, :account]])
  end

  def create(conn, %{"avatar" => params}) do
    create_or_update(conn, params, %Avatar{})
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

    promotion_error = owned_file_results |> Map.values() |> Enum.filter(&(elem(&1, 0) == :error)) |> Enum.at(0)

    case promotion_error do
      nil ->
        owned_files = owned_file_results |> Enum.map(fn {k, {:ok, file}} -> {k, file} end) |> Enum.into(%{})

        parent_avatar = params["parent_avatar_id"] && Repo.get_by(Avatar, avatar_sid: params["parent_avatar_id"])

        parent_avatar_listing =
          params["parent_avatar_listing_id"] &&
            Repo.get_by(AvatarListing, avatar_listing_sid: params["parent_avatar_listing_id"])

        {result, avatar} =
          avatar
          |> Avatar.changeset(account, owned_files, parent_avatar, parent_avatar_listing, params)
          |> Repo.insert_or_update()

        avatar = avatar |> Repo.preload(Avatar.file_columns())

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
  def show(conn, %AvatarListing{state: :delisted}), do: conn |> send_resp(404, "Avatar not found")

  def show(conn, %t{} = avatar) when t in [Avatar, AvatarListing] do
    account = conn |> Guardian.Plug.current_resource()
    conn |> render("show.json", avatar: avatar, account: account)
  end

  def show_avatar_gltf(conn, %{"id" => avatar_sid}) do
    conn |> show_gltf(avatar_sid |> get_avatar(), true)
  end

  def show_base_gltf(conn, %{"id" => avatar_sid}) do
    conn |> show_gltf(avatar_sid |> get_avatar(), false)
  end

  def show_gltf(conn, nil = _avatar, _apply_overrides) do
    conn |> send_resp(404, "Avatar not found")
  end

  def show_gltf(conn, %t{} = a, apply_overrides) when t in [Avatar, AvatarListing],
    do: conn |> show_gltf(a |> Avatar.collapsed_files(), apply_overrides)

  def show_gltf(conn, avatar_files, apply_overrides) do
    case Storage.fetch(avatar_files.gltf_owned_file) do
      {:ok, _meta, stream} ->
        gltf =
          stream
          |> Enum.join("")
          |> Poison.decode!()
          |> GLTFUtils.with_material(
            @primary_material_name,
            (apply_overrides && avatar_files |> Map.take(Avatar.image_columns())) || []
          )
          |> GLTFUtils.with_buffer(avatar_files.bin_owned_file)

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

  defp delete(conn, %Avatar{account_id: avatar_account_id}, %Account{account_id: account_id})
       when not is_nil(avatar_account_id) and avatar_account_id != account_id do
    conn |> send_resp(401, "You do not own this avatar")
  end

  defp delete(conn, %Avatar{} = avatar, %Account{}) do
    case Repo.delete(avatar) do
      {:ok, _} -> send_resp(conn, 200, "OK")
      {:error, error} -> render_error_json(conn, error)
    end
  end
end
