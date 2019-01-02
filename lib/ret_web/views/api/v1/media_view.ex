defmodule RetWeb.Api.V1.MediaView do
  use RetWeb, :view

  def render("show.json", %{
        file_id: file_id,
        origin: origin,
        raw: raw,
        meta: meta
      }) do
    %{file_id: file_id, origin: origin, raw: raw, meta: meta}
  end

  def render("show.json", %{origin: origin, raw: raw, meta: meta}) do
    %{origin: origin, raw: raw, meta: meta}
  end
end
