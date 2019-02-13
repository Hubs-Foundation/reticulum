defmodule RetWeb.Api.V1.AvatarController do
  use RetWeb, :controller

  alias Ret.{Account, Repo, Avatar, Storage, OwnedFile}

  plug(RetWeb.Plugs.RateLimit when action in [:create, :update])

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

        # avatar = avatar |> Repo.preload([:gltf_owned_file, :bin_owned_file])

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

  # TODO rename the refference images to something more reasonable
  @image_names %{
    base_map_owned_file: "Bot_PBS_BaseColor.jpg",
    emissive_map_owned_file: "Bot_PBS_Emmissive.jpg",
    normal_map_owned_file: "Bot_PBS_Normal.png",
    ao_metalic_roughness_map_owned_file: "Bot_PBS_Metallic.jpg"
  }

  @image_columns Map.keys(@image_names)
  @file_columns [:gltf_owned_file, :bin_owned_file] ++ @image_columns

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
    avatar = avatar_sid |> get_avatar()
    conn |> render("show.json", avatar: avatar)
  end

  def show_gltf(conn, %{"id" => avatar_sid}) do
    avatar =
      Avatar
      |> Repo.get_by(avatar_sid: avatar_sid)
      # TODO we ideally don't need to be featching the OwnedFiles until after we collapse them
      |> Avatar.load_parents(@file_columns)
      |> Map.from_struct()
      |> collapse_avatar_files()
      |> IO.inspect()

    case Storage.fetch(avatar.gltf_owned_file) do
      {:ok, %{"content_type" => content_type, "content_length" => content_length}, stream} ->
        image_customizations =
          @image_columns
          |> Enum.map(fn col -> customization_for_image(col, Map.get(avatar, col)) end)
          |> Enum.reject(&is_nil/1)

        IO.inspect(image_customizations)

        customizations = [
          {["images"], image_customizations},
          # This currently works because the input is known to have been a glb, which always has a single buffer which we exttract as part of upload
          {["buffers"],
           [
             %{
               uri: avatar.bin_owned_file |> OwnedFile.uri_for() |> URI.to_string()
             }
           ]}
        ]

        gltf =
          stream
          |> Enum.join("")
          |> Poison.decode!()
          |> apply_customizations(customizations)

        conn
        # |> put_resp_content_type("model/gltf", nil)
        |> send_resp(200, gltf |> Poison.encode!())

      {:error, :not_found} ->
        conn |> send_resp(404, "")

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end

  defp customization_for_image(_col, _owned_file = nil) do
    nil
  end

  defp customization_for_image(col, owned_file) do
    %{
      name: @image_names[col],
      uri: owned_file |> OwnedFile.uri_for() |> URI.to_string()
    }
  end

  defp apply_customizations(gltf, customization_set) do
    Enum.reduce(customization_set, gltf, &apply_customization/2)
  end

  # defp apply_customization({path = ["buffers"], replacements}, gltf) do
  #   gltf |> Kernel.put_in(path, replacements)
  # end

  defp apply_customization({path, replacements}, gltf) do
    gltf |> Kernel.update_in(path, &apply_replacement(&1, replacements))
  end

  # TODO this is currently hardcoded to match on name and always replaces the whole node. We likely will want to expand the format of a "customization" to include more details about how to match and what to do with matches
  defp apply_replacement(old_data, replacements) do
    Enum.map(old_data, fn old_value ->
      Enum.find(replacements, old_value, &(&1[:name] == old_value["name"]))
    end)
  end
end
