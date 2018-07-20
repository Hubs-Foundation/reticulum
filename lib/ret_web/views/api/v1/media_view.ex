defmodule RetWeb.Api.V1.MediaView do
  use RetWeb, :view

  def render("show.json", %{origin: origin, raw: raw, meta: meta, images: images}) do
    %{origin: origin, raw: raw, meta: meta, images: images}
  end
end
