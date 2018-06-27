defmodule RetWeb.Api.V1.MediaView do
  use RetWeb, :view

  def render("show.json", %{images: images}) do
    %{images: images}
  end
end
