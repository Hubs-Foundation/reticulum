defmodule RetWeb.Api.V1.AvatarController do
  use RetWeb, :controller

  alias Ret.{Account, Repo, Avatar, Storage, GLTFUtils}

  plug(RetWeb.Plugs.RateLimit when action in [:create, :update])

  @primary_material_name "Bot_PBS"

  defp get_avatar(avatar_sid) do
    Avatar
    |> Repo.get_by(avatar_sid: avatar_sid)
    |> Repo.preload([Avatar.file_columns() ++ [:parent_avatar, :account]])
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
    conn |> send_resp(401, "")
  end

  defp create_or_update(conn, params, avatar, account) do
    files_to_promote =
      (params["files"] || %{})
      |> Enum.map(fn {k, v} -> {String.to_atom(k), List.to_tuple(v)} end)
      |> Enum.into(%{})

    owned_file_results = Storage.promote(files_to_promote, account)

    promotion_error =
      owned_file_results |> Map.values() |> Enum.filter(&(elem(&1, 0) == :error)) |> Enum.at(0)

    case promotion_error do
      nil ->
        owned_files =
          owned_file_results |> Enum.map(fn {k, {:ok, file}} -> {k, file} end) |> Enum.into(%{})

        parent_avatar =
          params["parent_avatar_id"] &&
            Repo.get_by(Avatar, avatar_sid: params["parent_avatar_id"])

        {result, avatar} =
          avatar
          |> Avatar.changeset(account, owned_files, parent_avatar, params)
          |> Repo.insert_or_update()

        avatar = avatar |> Repo.preload(Avatar.file_columns())

        case result do
          :ok ->
            conn |> render("create.json", avatar: avatar)

          :error ->
            conn |> send_resp(422, "invalid avatar")
        end

      {:error, :not_found} ->
        conn |> send_resp(404, "no such file(s)")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end

  def show(conn, %{"id" => avatar_sid}) do
    conn |> show(avatar_sid |> get_avatar())
  end

  def show(conn, nil = _avatar) do
    conn |> send_resp(404, "")
  end

  def show(conn, %Avatar{} = avatar) do
    conn |> render("show.json", avatar: avatar)
  end

  def show_gltf(conn, %{"id" => avatar_sid}) do
    conn |> show_gltf(Avatar |> Repo.get_by(avatar_sid: avatar_sid))
  end

  def show_gltf(conn, nil = _avatar) do
    conn |> send_resp(404, "")
  end

  def show_gltf(conn, %Avatar{} = avatar) do
    avatar_files = avatar |> Avatar.collapsed_files()

    case Storage.fetch(avatar_files.gltf_owned_file) do
      {:ok, _meta, stream} ->
        gltf =
          stream
          |> Enum.join("")
          |> Poison.decode!()
          |> GLTFUtils.with_material(
            @primary_material_name,
            avatar_files |> Map.take(Avatar.image_columns())
          )
          |> GLTFUtils.with_buffer(avatar_files.bin_owned_file)

        conn
        # |> put_resp_content_type("model/gltf", nil)
        |> send_resp(200, gltf |> Poison.encode!())

      {:error, :not_found} ->
        conn |> send_resp(404, "")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end
end
