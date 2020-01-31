defmodule RetWeb.Api.V1.MediaView do
  use RetWeb, :view

  def render("show.json", %{
        file_id: file_id,
        origin: origin,
        meta: meta
      }) do
    %{file_id: file_id, origin: origin, meta: meta}
  end

  def render("show.json", %{origin: origin, origin_audio: origin_audio, meta: meta}) do
    %{origin: origin, origin_audio: origin_audio, meta: meta}
  end

  def render("show.json", %{origin: origin, meta: meta}) do
    %{origin: origin, meta: meta}
  end
end
