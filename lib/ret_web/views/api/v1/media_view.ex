defmodule RetWeb.Api.V1.MediaView do
  use RetWeb, :view

  def render("show.json", %{raw_image_url: raw_image_url}) do
    %{
      images: %{raw: raw_image_url}
    }
  end
end
