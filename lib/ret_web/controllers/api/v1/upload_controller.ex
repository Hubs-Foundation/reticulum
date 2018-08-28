defmodule RetWeb.Api.V1.UploadController do
  use RetWeb, :controller

  alias Ret.Upload
  alias Ret.Repo

  # Limit to 1 TPS
  plug(RetWeb.Plugs.RateLimit)

  def create(conn, %{
    "file" => %Plug.Upload{filename: filename, content_type: "application/octet-stream"} = file
  }) do
    create_with_content_type(conn, file, MIME.from_path(filename))
  end

  def create(conn, %{"file" => %Plug.Upload{content_type: content_type} = file}) do
    create_with_content_type(conn, file, content_type)
  end

  defp create_with_content_type(conn, %Plug.Upload{} = file, content_type) do
    key = Application.get_env(:ret, :upload_encryption_key) |> Base.decode16!(case: :lower)
    case Ret.Uploads.store(file, content_type, key) do
      {:ok, upload_uuid} ->
        {result, upload} =
          %Upload{}
          |> Upload.changeset(%{
            :upload_uuid => upload_uuid,
            # TODO BP: Need actual authentication here
            :uploader_account_id => 1234
          })
          |> Repo.insert(returning: true)

        case result do
          :ok -> render(conn, "create.json", upload: upload)
          :error -> conn |> send_resp(422, "invalid upload")
        end

      {:error, :not_allowed} ->
        conn |> send_resp(401, "")
    end
  end
end
