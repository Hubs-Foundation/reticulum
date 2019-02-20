defmodule RetWeb.Api.V1.AvatarController do
  use RetWeb, :controller

  alias Ret.{Account, Repo, Avatar, Storage, OwnedFile}

  plug(RetWeb.Plugs.RateLimit when action in [:create, :update])

  @texture_paths %{
    base_map_owned_file: [["pbrMetallicRoughness", "baseColorTexture"]],
    emissive_map_owned_file: [["emissiveTexture"]],
    normal_map_owned_file: [["normalTexture"]],
    orm_map_owned_file: [
      ["pbrMetallicRoughness", "metallicRoughnessTexture"],
      ["occlusionTexture"]
    ]
  }
  @image_columns Map.keys(@texture_paths)
  @file_columns [:gltf_owned_file, :bin_owned_file] ++ @image_columns

  def create(conn, %{"avatar" => params}) do
    create_or_update(conn, params, %Avatar{})
  end

  def update(conn, %{"id" => avatar_sid, "avatar" => params}) do
    case avatar_sid |> get_avatar() do
      %Avatar{} = avatar -> create_or_update(conn, params, avatar)
      _ -> conn |> send_resp(404, "not found")
    end
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

  defp create_or_update(conn, params, avatar) do
    account = conn |> Guardian.Plug.current_resource()

    files_to_promotoe =
      case params["files"] do
        nil ->
          %{}

        files ->
          files
          |> Enum.map(fn {k, v} -> {String.to_atom(k), List.to_tuple(v)} end)
          |> Enum.into(%{})
      end

    owned_file_results = Storage.promote(files_to_promotoe, account)

    promotion_error =
      owned_file_results |> Map.values() |> Enum.filter(&(elem(&1, 0) == :error)) |> Enum.at(0)

    case promotion_error do
      nil ->
        owned_files =
          owned_file_results |> Enum.map(fn {k, {:ok, file}} -> {k, file} end) |> Enum.into(%{})

        IO.inspect(params["parent_avatar_id"])

        parent_avatar =
          if params["parent_avatar_id"] do
            Repo.get_by(Avatar, avatar_sid: params["parent_avatar_id"])
          end

        IO.inspect(parent_avatar)

        {result, avatar} =
          avatar
          |> Avatar.changeset(account, owned_files, parent_avatar, params)
          |> IO.inspect()
          |> Repo.insert_or_update()

        IO.inspect(avatar)

        avatar = avatar |> Repo.preload(@file_columns)

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

  defp collapse_avatar_files(%{parent_avatar: nil} = avatar),
    do: avatar |> Map.take(@file_columns)

  defp collapse_avatar_files(%{parent_avatar: parent} = avatar) do
    Map.merge(collapse_avatar_files(parent), avatar |> Map.take(@file_columns), fn _k, v1, v2 ->
      if is_nil(v2), do: v1, else: v2
    end)
  end

  defp get_avatar(avatar_sid) do
    avatar =
      Avatar
      |> Repo.get_by(avatar_sid: avatar_sid)
      |> Repo.preload([@file_columns ++ [:parent_avatar, :account]])
      |> IO.inspect()
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
    # TODO we ideally don't need to be featching the OwnedFiles until after we collapse them
    avatar =
      avatar
      |> Avatar.load_parents(@file_columns)
      |> Map.from_struct()
      |> collapse_avatar_files()

    case Storage.fetch(avatar.gltf_owned_file) do
      {:ok, %{"content_type" => content_type, "content_length" => content_length}, stream} ->
        gltf =
          stream
          |> Enum.join("")
          |> Poison.decode!()
          |> with_material("Bot_PBS", avatar)
          |> with_buffer(avatar.bin_owned_file)

        conn
        # |> put_resp_content_type("model/gltf", nil)
        |> send_resp(200, gltf |> Poison.encode!())

      {:error, :not_found} ->
        conn |> send_resp(404, "")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end

  defp with_buffer(gltf, bin_file) do
    gltf
    |> Map.replace("buffers", [
      %{
        uri: bin_file |> OwnedFile.uri_for() |> URI.to_string()
      }
    ])
  end

  defp with_material(gltf, name, avatar) do
    case gltf["materials"] |> Enum.find(&(&1["name"] == name)) do
      nil ->
        gltf

      material ->
        image_files =
          avatar
          |> Map.take(@image_columns)
          |> Enum.filter(fn {_, v} -> v end)

        image_files
        |> Enum.flat_map(fn {col, file} ->
          Enum.map(@texture_paths[col], fn path ->
            texture_index = material |> Kernel.get_in(path ++ ["index"])
            image_index = gltf |> Kernel.get_in(["textures", Access.at(texture_index), "source"])
            {image_index, file}
          end)
        end)
        |> Enum.reduce(gltf, fn {index, file}, gltf ->
          gltf
          |> Kernel.put_in(["images", Access.at(index)], %{
            uri: file |> OwnedFile.uri_for() |> URI.to_string(),
            mimeType: file.content_type
          })
        end)
    end
  end
end
