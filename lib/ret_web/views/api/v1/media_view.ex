defmodule RetWeb.Api.V1.MediaView do
  use RetWeb, :view

  def render("show.json", %{raw: raw, images: images}) do
    %{raw: raw, images: images}
  end
end
