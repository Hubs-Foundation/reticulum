defmodule RetWeb.Api.V1.UploadView do
  use RetWeb, :view
  alias Ret.Upload

  def render("create.json", %{upload: upload}) do
    %{
      status: :ok,
      upload_id: to_string(upload.upload_id)
    }
  end
end
