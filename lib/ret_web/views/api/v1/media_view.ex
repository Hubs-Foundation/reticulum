defmodule RetWeb.Api.V1.MediaView do
  use RetWeb, :view

  def render("show.json", %{
        file_id: file_id,
        origin: origin,
        raw: raw,
        meta: meta,
        images: images
      }) do
    %{file_id: file_id, origin: origin, raw: raw, meta: meta, images: images}
  end

  def render("show.json", %{origin: origin, raw: raw, meta: meta, images: images}) do
    %{origin: origin, raw: raw, meta: meta, images: images}
  end
end
