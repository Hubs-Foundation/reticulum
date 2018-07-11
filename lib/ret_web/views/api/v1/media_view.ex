defmodule RetWeb.Api.V1.MediaView do
  use RetWeb, :view

  def render("show.json", %{origin: origin, raw: raw, meta: nil, images: images}) do
    %{origin: origin, raw: raw, images: images}
  end

  def render("show.json", %{
        meta: meta,
        origin: origin,
        raw: raw,
        images: images
      }) do
    %{meta: meta, origin: origin, raw: raw, images: images}
  end
end
