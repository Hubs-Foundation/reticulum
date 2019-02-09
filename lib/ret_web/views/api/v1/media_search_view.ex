defmodule RetWeb.Api.V1.MediaSearchView do
  use RetWeb, :view

  def render("index.json", %{results: results}) do
    results
  end
end
